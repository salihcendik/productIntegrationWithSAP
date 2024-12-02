/**
 * ProductIntegrationBatch is used for product integration with SAP S4HANA.
 * This batch class is scheduled with the TR_ProductIntegrationScheduleBundle job to sync or update product data with SAP.
 *
 * Parameters:
 *  - lastUpdate: The last update date for product data (e.g., '2024-11-10'). This can be set to null if not applicable.
 *  - salesOrg: Sales organization ID (e.g., '2501'). This can be set to null if not applicable.
 *  - productCodes: A set of product codes to process (e.g., {'1020DB1M0010'}). This can be set to null if not applicable.
 *
 * Important: The batch size must be set to 1 for this batch to function correctly.
 *
 * Log Details: You can view log details in the Logger Console from the App Launcher.
 *
 * To manually trigger this batch class, use:
 * Database.executeBatch(new ProductIntegrationBatch('2024-11-10', '2501', new Set<String>{'1020DB1M0010'}), 1);
 *
 * Example Usage:
 * Database.executeBatch(new ProductIntegrationBatch('YYYY-MM-DD', 'SalesOrgID', new Set<String>{'ProductCode1', 'ProductCode2'}), 1);
 */


public with sharing class ProductIntegrationBatch implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful{
    private static final String ORIGIN_CLASS = ProductIntegrationBatch.Class.getName();
    private static final Integer BATCH_SIZE = 100; //This value defined in SAP as Static.
    private static final String COMPANY_VITRA_KARO = '2100';
    private static final String COMPANY_VILLEROY_BOCH = '2200';
    private static final String COMPANY_PLITKA = '2300';
    public String originalTransactionId;
    public String callDate;
    public String salesOrg;
    public Set<String> productSAPCodes;
    
    public ProductIntegrationBatch() {
        this.callDate = getCallDate();
    }

    public ProductIntegrationBatch(String callDate, String salesOrg, Set<String> productSAPCodes) {
        this.callDate = callDate;
        this.salesOrg = salesOrg;
        this.productSAPCodes = productSAPCodes;
    }
    //START ============>
    public Iterable<Integer> start(Database.BatchableContext bc) {
        this.originalTransactionId = Logger.getTransactionId();
        Logger.info('Starting Product Integration Batch with S4HANA...');
        try {
            return generateBatchIndexes();
        } catch(Exception e) {
            Logger.error(e.getLineNumber() + ' -> ' + e.getMessage());
            return new List<Integer>();
        } finally {
            Logger.saveLog();
        }
    }
    //EXECUTE ============>
    public void execute(Database.BatchableContext bc, List<Integer> indexes){
        Logger.setParentLogTransactionId(this.originalTransactionId);
        validateBatchSize(indexes);
        try {
            processProducts(indexes[0]);
        } catch(Exception e) {
            Logger.error(e.getLineNumber() + ' -> ' + e.getMessage());
        } finally {
            Logger.saveLog();
        }
    }
    //FINISH ============>
    public void finish(Database.BatchableContext bc){
        Logger.setParentLogTransactionId(this.originalTransactionId);
        Logger.info('Finishing the execution of Product Integration Batch with S4HANA.');
        Logger.saveLog();
        ECZUtil.updateCustomSettingFields('TR_Settings', 'Product_Integration_Running_Date__c' );
    }
    //=============================================================================================

    private List<Integer> generateBatchIndexes() {
        EZC_TR_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element response = sendRequest(null);
        Integer totalSize = response.ET_SIZE.item[0].SIZE;
        Integer calloutCount = calculateCalloutCount(totalSize);
        
        List<Integer> indexes = new List<Integer>();
        for (Integer i = 0; i < calloutCount; i++) {
            indexes.add(i * BATCH_SIZE);
        }
        
        logBatchInfo(totalSize, calloutCount, indexes);
        return indexes;
    }

    private Integer calculateCalloutCount(Integer totalSize) {
        return (totalSize/BATCH_SIZE) + 1;
    }

    private void logBatchInfo(Integer totalSize, Integer calloutCount, List<Integer> indexes) {
        Logger.info('Total Product Size: ' + totalSize);
        Logger.info('Count of requests (total batches): ' + calloutCount);
        Logger.info('Indexes: ' + JSON.serialize(indexes));
    }

    private void validateBatchSize(List<Integer> indexes) {
        if (indexes.size() != 1) {
            throw new HandledException('Batch size must be 1');
        }
    }

    private void processProducts(Integer index) {
        Logger.info('Current index: ' + index);
        EZC_TR_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element response = sendRequest(index);
        upsertProductWithRelationsInSalesForce(response);
    }

    public EZC_TR_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element sendRequest(Integer requestIndex) {
        EZC_TR_Product_DataModel.IR_MATNR_element IR_MATNR;
        EZC_TR_Product_DataModel.IR_VKORG_element IR_VKORG; 
        EZC_TR_Product_DataModel.IT_INDEX_element IT_INDEX; 
        String IV_DATE = this.callDate;
        String IV_LVORM;
        if (this.productSAPCodes != null && !this.productSAPCodes.isEmpty()){
            IR_MATNR = generateMatnrElement();
        }
        if (!String.isEmpty(this.salesOrg)){
            IR_VKORG = generateVkorgElement();
        }
        if(requestIndex != null) {
            IT_INDEX = generateIndexElement(requestIndex);
        }
        ECZ_TR_ProductIntegration.HTTPS_Port callWS = new ECZ_TR_ProductIntegration.HTTPS_Port();
        callWS.inputHttpHeaders_x = new Map<String,String>();
        callWS.inputHttpHeaders_x.put('Content-Type', 'text/xml;charset = UTF-8');
        EZC_TR_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element response = callWS.SI_sf_product_get_tr_OB(IR_MATNR, IR_VKORG, IT_INDEX, IV_DATE, IV_LVORM);
        this.validateResponse(response);
        return response;
    } 

    public void upsertProductWithRelationsInSalesForce(EZC_TR_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element res){
        Map<String, String> productCodeIdMap = upsertProducts(res.ET_PRODUCT.item);
        upsertSalesOrgs(res.ET_PRODUCT.item, productCodeIdMap);
        upsertProductConversions(res.ET_PRODUCT.item, productCodeIdMap);
        upsertProductTranslations(res.ET_PRODUCT.item, productCodeIdMap);
    }

    public Map<String, String> upsertProducts(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products) {
        Map<String, String> prodHierarchyMap = getProdHierarchyMap(products);
        List<Product2> productsToUpsert = transformProducts(products, prodHierarchyMap);
        return performUpsert(productsToUpsert);
    }

    private Map<String, String> getProdHierarchyMap(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products) {
        Set<String> hierarchyCodes = new Set<String>();
        for(EZC_TR_Product_DataModel.ZMM_S_PRODUCT product : products) {
            hierarchyCodes.addAll(new Set<String>{
                COMPANY_VITRA_KARO + '_' + product.PRDH1,
                COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2,
                COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2 + product.PRDH3,
                COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2 + product.PRDH3 + product.PRDH4,
                COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2 + product.PRDH3 + product.PRDH4 + product.PRDH5
            });
        }
        
        Map<String, String> hierarchyMap = new Map<String, String>();
        for(Hierarchy__c hierarchy : [SELECT Id, SAP_Code__c FROM Hierarchy__c WHERE SAP_Code__c IN :hierarchyCodes]) {
            hierarchyMap.put(hierarchy.SAP_Code__c, hierarchy.Id);
        }
        return hierarchyMap;
    }

    private String getProductNameByTR(List<EZC_TR_Product_DataModel.ZMM_S_MAKT> langs) {
        String productTRName;
        if (langs == null || langs.isEmpty()) return productTRName;
        for(EZC_TR_Product_DataModel.ZMM_S_MAKT lang : langs) {
            if(lang.SPRAS == 'T') {
                productTRName = lang.MAKTX;
                break;
            }
        }
        return productTRName;
    }

    private String getMRPController(List<EZC_TR_Product_DataModel.ZMM_S_MARC> plants) {
        String mrpCont;
        if (plants == null || plants.isEmpty()) return mrpCont;
        for(EZC_TR_Product_DataModel.ZMM_S_MARC plant : plants) {
            if(plant.WERKS == '2110') {
                mrpCont = plant.DISPO;
                break;
            }
        }
        return mrpCont;
    }

    private List<Product2> transformProducts(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products, Map<String, String> hierarchyMap) {
        List<Product2> transformedProducts = new List<Product2>();
        Id productRecordTypeId = Schema.SObjectType.Product2.getRecordTypeInfosByName().get('TR Product').getRecordTypeId();
        
        for(EZC_TR_Product_DataModel.ZMM_S_PRODUCT product : products) {
            Product2 prod = new Product2();
            prod.Company__c = COMPANY_VITRA_KARO;
            prod.SAP_Number__c = COMPANY_VITRA_KARO + '_' + product.MATNR;
            prod.RecordTypeId = productRecordTypeId;
            prod.Name = getProductNameByTR(product.LANG?.item);
            prod.MRPCn__c = getMRPController(product.PLANT?.item);
            prod.ProductCode = product.MATNR;
            prod.MaterialType__c = product.MTART;
            prod.QuantityUnitOfMeasure = product.MEINS;
            prod.BaseUnitOfMeasure__c = product.MEINS;
            prod.MaterialGroup__c = product.MATKL;
            prod.Share__c = product.SPART;
            prod.ProductHierarchy__c = product.PRDHA;
            prod.ProductHierarchy1__c = hierarchyMap.get(COMPANY_VITRA_KARO + '_' + product.PRDH1);
            prod.ProductHierarchy2__c = hierarchyMap.get(COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2);
            prod.ProductHierarchy3__c = hierarchyMap.get(COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2 + product.PRDH3);
            prod.ProductHierarchy4__c = hierarchyMap.get(COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2 + product.PRDH3 + product.PRDH4);
            prod.ProductHierarchy5__c = hierarchyMap.get(COMPANY_VITRA_KARO + '_' + product.PRDH1 + product.PRDH2 + product.PRDH3 + product.PRDH4 + product.PRDH5);
            prod.OldMaterialNumber__c = product.BISMT;
            prod.GrossWeight__c = product.BRGEW != null ? String.valueOf(product.BRGEW) : null;
            prod.NetWeight__c = product.NTGEW != null ? String.valueOf(product.NTGEW) : null;
            prod.WeightUnit__c = product.GEWEI; 
            prod.EANCodes__c = product.EAN11;
            prod.EanType__c = product.NUMTP; 
            prod.Capacity_Group__c = product.ZZEKSKTGRP;
            prod.MixBlockNo__c = product.ZZMIXB_NO != null ? Decimal.valueOf(product.ZZMIXB_NO) : null;
            prod.NettingDrawingNumber__c = product.ZZ_FILELEME_CIZNO;
            prod.NettingType__c = product.ZZ_FILELEME_TIPI;
            prod.GeneralItemCategoryGroup__c = product.MTPOS_MARA;
            prod.CrossDistributionChainMaterialStatus__c = product.MSTAV;
            prod.XDistrChainMaterialStatusValidityDate__c = product.MSTDV;
            prod.CrossPlantMaterialStatus__c = product.MSTAE;
            prod.CrossPlantMaterialStatusValidityDate__c = product.MSTDE;
            prod.NominalSize__c = product.ZZANMAEBADE;
            prod.ProductSize__c = product.ZZURUNEBADE;
            prod.FrostResistance__c = product.ZZDONMADAYANIMI;
            prod.Abrasion__c = product.ZZASINMADEGERI;
            prod.SlipResistance__c = product.ZZRKAYMAZLIGI;
            prod.BarefootSlipResistance__c = product.ZZCPAYAKKAYMAZ;
            prod.Surface__c = product.ZZEKSRENK;
            prod.ProductYear__c = product.ZZURETYEAR;
            prod.Upec__c = product.ZZUPEC;
            prod.ProductColour__c = product.ZZEKS_URNR;
            prod.ColourGroup__c = product.ZZ_RENK_GRUBU;
            prod.BodyType__c = product.ZZYUZEY;
            prod.GlazedEdge__c = product.ZZYUZTP;
            prod.NetType__c = product.ZZVLAVABO;
            prod.ProtectionTechnology__c = product.ZZVSIFON;
            prod.MasseType__c = product.ZZVYON;
            prod.Body__c = product.ZZBUNYE;
            prod.KlinSKU__c = product.ZZICRFCODE;
            prod.Brand__c = product.ZZICRBRAND;
            prod.Relief__c = product.ZZICRROLYEF;
            prod.SurfaceFinish__c = product.ZZICRSURFACEFINISH;
            prod.Pendulum4S96Dry__c = product.ZZ_KARO_PEN96K;
            prod.Pendulum4S96Wet__c = product.ZZ_KARO_PEN96I;
            prod.PendulumTRL55Dry__c = product.ZZ_KARO_PENTRLK;
            prod.PendulumTRL55Wet__c = product.ZZ_KARO_PENTRLI;
            prod.DCOF__c = product.ZZ_KARO_DCOF;
            prod.BoxCode__c = product.ZZ_KARO_KUTUKODU;
            prod.SupportWood__c = product.ZZ_KARO_YANPALET;
            prod.GLUGL__c = product.ZZ_KARO_MADEINTURKEY;
            prod.PalletType__c = product.ZZ_KARO_PALETTIPI;
            prod.SpecialPackagingForDecors__c = product.ZZ_DEKOR_OZEL_PAKETLEME;
            prod.DiscountedProductDate__c = product.ZGECTAR4;
            prod.VolumeUnit__c = product.VOLEH;
            prod.Rotocolor__c = product.ZZICRROTOCOLOR;
            prod.Digital__c = product.ZZICRDIGITAL;
            prod.MISNumber__c = product.ZZ_MIS_GIRDI_KODU;
            prod.ProductionKilnDimension__c = product.ZZICRPRODUCTKILNDIM;
            prod.DerivativeCode__c = product.ZZ_KARO_TUREMEKODU;
            prod.TransitGroup__c = product.TRAGR;
            prod.IsActive = product.LVORM == 'X' ? false : true;
            prod.Segment__c = product.YYSGM;
            prod.Material__c = product.YYWS;
            prod.Color_Number__c = product.YYCLRNUM;
            prod.Color_Text__c = product.YYCOLORTXT;
            prod.RAL_Code__c = product.YYRALCODE;
            prod.Price_Gruppe__c = product.YYPRGRGER;
            prod.Design__c = product.YYDesign;
            prod.Plan_Status__c = product.YYVTS;
            prod.In_Pricebook__c = product.YYPRICELIST == 'X' ? true : false;
            prod.Width__c = product.BREIT;
            prod.Length__c = product.LAENG;
            prod.Height__c = product.HOEHE;
            prod.Custom_Made__c = product.YYETIKE;
            prod.Standard_Artikel__c = product.YVPMAT;
            prod.Thickness__c = product.YYTHIC;
            prod.SizeDimension__c = product.GROES;
            prod.SureFootednessNonSlipCommercial__c = product.YRUHM2;
            prod.SureFootednessSlipResistanceBarefootArea__c = product.YRUHM1;
            prod.Glaze__c = product.YYGLAZ;
            prod.MixBlockSummary__c = product.FORMUL;
            prod.Volumes__c = product.VOLUM;
            if(product.ZZICRSERINO != null) { 
                prod.SerialNo__r = new Definition2__c(SAPCode__c = COMPANY_VITRA_KARO + '_' + product.ZZICRSERINO);
            }
            transformedProducts.add(prod);
        }
        return transformedProducts;
    }   

    private Map<String, String> performUpsert(List<Product2> products) {
        Map<String, String> resultMap = new Map<String, String>();
        if(products.isEmpty()) return resultMap;
        
        Database.UpsertResult[] results = Database.upsert(products, Product2.SAP_Number__c, false);
        List<String> errors = new List<String>();
        
        for(Integer i = 0; i < results.size(); i++) {
            if(results[i].isSuccess()) {
                resultMap.put(products[i].ProductCode, results[i].getId());
            } else {
                for(Database.Error err : results[i].getErrors()) {
                    errors.add(err.getStatusCode() + ': ' + err.getMessage() + ' Fields that affected this error: ' + err.getFields() + ' SapCode: ' + products[i].ProductCode);
                }
            }
        }
        
        if(!errors.isEmpty()) {
            Logger.error('Product upsert errors:\n' + String.join(errors, '\n'));
        }else{
            Logger.info('Products -> Number of records successfully saved : ' + results.size());
        }
        
        return resultMap;
    }

    public void upsertSalesOrgs(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products, Map<String, String> productCodeIdMap) {
        List<Product_Sales_Org__c> salesOrgs = transformSalesOrgs(products, productCodeIdMap);
        performUpsert(salesOrgs);
    }

    private List<Product_Sales_Org__c> transformSalesOrgs(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products, Map<String, String> productCodeIdMap) {
        List<Product_Sales_Org__c> salesOrgs = new List<Product_Sales_Org__c>();
        Id salesOrgRecordTypeId = Schema.SObjectType.Product_Sales_Org__c.getRecordTypeInfosByName().get('Product Sales Org TR').getRecordTypeId();
        
        for(EZC_TR_Product_DataModel.ZMM_S_PRODUCT product : products) {
            if(!productCodeIdMap.containsKey(product.MATNR) || product?.ORG.item == null) continue;
            
            for(EZC_TR_Product_DataModel.ZMM_S_MVKE org : product.ORG.item) {
                String companyCode = getCompanyCode(org.VKORG);
                Product_Sales_Org__c salesOrg = createSalesOrg(product, org, companyCode,  productCodeIdMap.get(product.MATNR), salesOrgRecordTypeId);
                salesOrgs.add(salesOrg);
            }
        }
        return salesOrgs;
    }

    private Product_Sales_Org__c createSalesOrg(EZC_TR_Product_DataModel.ZMM_S_PRODUCT product,
                                            EZC_TR_Product_DataModel.ZMM_S_MVKE org,
                                            String companyCode,
                                            String productId,
                                            Id recordTypeId) {

        Product_Sales_Org__c prodSalesOrg = new Product_Sales_Org__c(
            Product__c = productId,
            RecordTypeId = recordTypeId,
            SAPNumber__c = String.format('{0}_{1}_{2}_{3}_{4}', 
                new String[]{companyCode, product.MATNR, org.VKORG, org.VTWEG, org.SPART}),
            SalesOrg__c = org.VKORG,
            DistributionChannel__c = companyCode == COMPANY_VILLEROY_BOCH ? org.VTWEG + 'DE' : org.VTWEG,
            Segment__c = org.MVGR3,
            Material_Group__c = org.MVGR3,
            V_B_Production__c = org.PRAT1,
            Turkey_Production__c = org.PRAT3,
            SSKU__c = org.PRAT5,
            Opportunity__c = org.PRAT8,
            Distribution_chain_spec_material_status__c = org.VMSTA,
            Delivery_Quantity__c = org.SCMNG != null ? Decimal.valueOf(org.SCMNG) : 0,
            Unit_of_measure_of_delivery_unit__c = org.SCHME,
            Acc_assignment_group_for_this_material__c = org.KTGRM,
            Item_Category_Group__c = org.MTPOS,
            Sales_Unit__c = org.VRKME,
            Division__c = org.VKORG == '2301' ? '60' : org.SPART,
            Minimum_Order_Quantity__c = org.AUMNG != null ? Decimal.valueOf(org.AUMNG) : 0,
            Transit_Sales__c = org.ZZ_TRANSIT_SATIS != null ? Boolean.valueOf(org.ZZ_TRANSIT_SATIS) : false
        );
        setValidDate(prodSalesOrg, org.VMSTD);
        return prodSalesOrg;
    }
    
    private void performUpsert(List<Product_Sales_Org__c> salesOrgs) {
        if(salesOrgs.isEmpty()) return;
        
        Database.UpsertResult[] results = Database.upsert(salesOrgs, Product_Sales_Org__c.SAPNumber__c, false);
        new IntegrationDatabaseLogger(ORIGIN_CLASS, 'Product Sales Orgs -> ').logUpsertResults(salesOrgs, results);
    }

    public void upsertProductConversions(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products, Map<String, String> productCodeIdMap) {
        List<ProductConvertion__c> conversions = transformProductConversions(products, productCodeIdMap);
        performUpsert(conversions);
    }

    private List<ProductConvertion__c> transformProductConversions(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products, Map<String, String> productCodeIdMap) {
        List<ProductConvertion__c> conversions = new List<ProductConvertion__c>();
        
        for(EZC_TR_Product_DataModel.ZMM_S_PRODUCT product : products) {
            if(!productCodeIdMap.containsKey(product.MATNR) || product?.UNIT.item == null) continue;
            
            for(EZC_TR_Product_DataModel.ZMM_S_MARM conversion : product.UNIT.item) {
                ProductConvertion__c conv = new ProductConvertion__c(
                    Product__c = productCodeIdMap.get(product.MATNR),
                    SAPNumber__c = COMPANY_VITRA_KARO + '_' + product.MATNR + '_' + conversion.MEINH,
                    Unit__c = conversion.MEINH,
                    Quantity__c = conversion.UMREN != null ? Decimal.valueOf(conversion.UMREN) : null,
                    ConversionRate__c = conversion.UMREZ != null ? Decimal.valueOf(conversion.UMREZ) : null
                );
                conversions.add(conv);
            }
        }
        return conversions;
    }

    private void performUpsert(List<ProductConvertion__c> conversions) {
        if(conversions.isEmpty()) return;
        
        Database.UpsertResult[] results = Database.upsert(conversions, ProductConvertion__c.SAPNumber__c, false);
        new IntegrationDatabaseLogger(ORIGIN_CLASS, 'Product Conversions -> ').logUpsertResults(conversions, results);
    }

    public void upsertProductTranslations(List<EZC_TR_Product_DataModel.ZMM_S_PRODUCT> products, Map<String,String> productCodeIdMap){
        List<Product2DataTranslation> upsertProductTranslations = new List<Product2DataTranslation>();
        for(EZC_TR_Product_DataModel.ZMM_S_PRODUCT product : products) {
            if(!productCodeIdMap.containsKey(product.MATNR) || product?.LANG.item == null) continue;

            for(EZC_TR_Product_DataModel.ZMM_S_MAKT productTranslate : product?.LANG.item) {
                if(productTranslate.SPRAS == 'R' || productTranslate.SPRAS == 'T' || productTranslate.SPRAS == 'E' || productTranslate.SPRAS == 'D'){
                    Product2DataTranslation productTranslation = new Product2DataTranslation();
                    productTranslation.ParentId = productCodeIdMap.get(product.MATNR);
                    productTranslation.Name = productTranslate.MAKTX;
                    switch on productTranslate.SPRAS {
                        when 'R' {
                            productTranslation.Language = 'ru';
                        }
                        when 'D' {
                            productTranslation.Language = 'de';
                        }
                        when 'T' {
                            productTranslation.Language = 'tr';
                        }
                        when 'E' {
                            productTranslation.Language = 'en_US';
                        }
                    }
                    upsertProductTranslations.add(productTranslation);
                }
            }
        }
        if(!upsertProductTranslations.isEmpty()) {
            Database.UpsertResult[] upsertList = Database.upsert(upsertProductTranslations, false);
        }
    }

    public String getCallDate(){
        Integration_Settings__c settings = Integration_Settings__c.getValues('TR_Settings');
        Date runningDate = settings.Product_Integration_Running_Date__c;
        if(runningDate == null) {
            return null;
        }
        DateTime newCallDate = Datetime.newInstance(runningDate.year(), runningDate.month(), runningDate.day());
        return newCallDate.format('YYYY-MM-dd');
    }

    public EZC_TR_Product_DataModel.IT_INDEX_element generateIndexElement(Integer index){
        EZC_TR_Product_DataModel.IT_INDEX_element indexElements = new EZC_TR_Product_DataModel.IT_INDEX_element();
        EZC_TR_Product_DataModel.ZMM_SF_S_INDEX indexElement = new EZC_TR_Product_DataModel.ZMM_SF_S_INDEX();
        indexElement.TAB_NAME = 'ET_PRODUCT';
        indexElement.INDEX = index;
        indexElements.item = new List<EZC_TR_Product_DataModel.ZMM_SF_S_INDEX>{indexElement};
        return indexElements;
    }

    public EZC_TR_Product_DataModel.IR_MATNR_element generateMatnrElement(){
        EZC_TR_Product_DataModel.IR_MATNR_element matnrElement = new EZC_TR_Product_DataModel.IR_MATNR_element();
        List<EZC_TR_Product_DataModel.CURTO_MATNR_RANGE> matnrElements = new List<EZC_TR_Product_DataModel.CURTO_MATNR_RANGE>();
        for(String productCode: this.productSAPCodes){
            EZC_TR_Product_DataModel.CURTO_MATNR_RANGE matnr = new EZC_TR_Product_DataModel.CURTO_MATNR_RANGE();
            matnr.SIGN = 'I';
            matnr.OPTION = 'EQ';
            matnr.LOW = productCode;
            matnrElements.add(matnr);
        }
        matnrElement.item = matnrElements;
        return matnrElement;
    }

    public EZC_TR_Product_DataModel.IR_VKORG_element generateVkorgElement(){
        EZC_TR_Product_DataModel.IR_VKORG_element vkorgElement = new EZC_TR_Product_DataModel.IR_VKORG_element();
        EZC_TR_Product_DataModel.WTYSC_WWB_S_VKORG vkorg = new EZC_TR_Product_DataModel.WTYSC_WWB_S_VKORG();
        vkorg.SIGN = 'I';
        vkorg.OPTION = 'EQ';
        vkorg.LOW = this.salesOrg;
        vkorgElement.item = new List<EZC_TR_Product_DataModel.WTYSC_WWB_S_VKORG>{vkorg};
        return vkorgElement;
    }

    public void setValidDate(Product_Sales_Org__c salesOrg, String VMSTD){
        if(VMSTD != null && VMSTD != '0000-00-00') {
            String dateString = String.valueOf(VMSTD);
            List<String> splittedDate = dateString.split('-');
            if(Integer.valueOf(splittedDate[0]) > 4000) {
                splittedDate[0] = '4000';
            }
            Date newValidDate = Date.newInstance(Integer.valueOf(splittedDate[0]), Integer.valueOf(splittedDate[1]), Integer.valueOf(splittedDate[2]));
            salesOrg.Valid_Date__c = newValidDate;
        }
    }

    public String getCompanyCode(String salesOrg){
        return salesOrg?.substring(0, 2).rightPad(4, '0');
    }

    private void validateResponse(EZC_TR_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element response) {
        if (response?.ET_MESS != null && response.ET_MESS.item[0].TYPE_x == 'E') {
            String errorMessage = response.ET_MESS.item[0].MESS;
            throw new CalloutException('Integration failed with the following service response: ' + errorMessage);
        }
        
        if (response?.ET_PRODUCT.item == null || response?.ET_PRODUCT.item.isEmpty()) {
            String emptyProductMessage = 'There is no updated product because ET_PRODUCT table is empty';
            throw new CalloutException(emptyProductMessage);
        }
    }
}