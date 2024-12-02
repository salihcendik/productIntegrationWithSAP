/**
 * @last modified on  : 30-10-2023
 * @last modified by  : salih.cendik
**/

@IsTest
global class ProductIntegrationMock implements WebServiceMock {
    
    global void doInvoke(
        Object stub,
        Object request,
        Map<String, Object> response,
        String endpoint,
        String soapAction,
        String requestName,
        String responseNS,
        String responseName,
        String responseType) {
            
            SAP_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element response_x = new SAP_Product_DataModel.ZMM_FM_GET_PRODUCT_Response_element();
            
            //*** ET_INDEX ***
            SAP_Product_DataModel.ET_INDEX_element ET_INDEX = new SAP_Product_DataModel.ET_INDEX_element();
            List<SAP_Product_DataModel.ZMM_SF_S_INDEX> etIndex_List = new List<SAP_Product_DataModel.ZMM_SF_S_INDEX>();
            SAP_Product_DataModel.ZMM_SF_S_INDEX etIndex_item = new SAP_Product_DataModel.ZMM_SF_S_INDEX();
            etIndex_item.TAB_NAME = 'ET_PRODUCT';
            etIndex_item.INDEX = 0;
            etIndex_List.add(etIndex_item);
            ET_INDEX.item = etIndex_List;

            //*** ET_MESS ***
            SAP_Product_DataModel.ET_MESS_element ET_MESS = new SAP_Product_DataModel.ET_MESS_element();
            List<SAP_Product_DataModel.ZMM_S_MESS> etMess_List = new List<SAP_Product_DataModel.ZMM_S_MESS>();
            SAP_Product_DataModel.ZMM_S_MESS etMess_item = new SAP_Product_DataModel.ZMM_S_MESS();
            etMess_item.MESS = 'MESS';
            etMess_item.TYPE_x = 'TYPE_x';
            etMess_List.add(etMess_item);
            ET_MESS.item = etMess_List;
            
            //*** ORG ****
            SAP_Product_DataModel.ZMM_TT_MVKE ORG = new SAP_Product_DataModel.ZMM_TT_MVKE();
            List<SAP_Product_DataModel.ZMM_S_MVKE> org_List = new List<SAP_Product_DataModel.ZMM_S_MVKE>();
            SAP_Product_DataModel.ZMM_S_MVKE org_item = new SAP_Product_DataModel.ZMM_S_MVKE();
            org_item.MATNR = '100';
            org_item.VMSTD = String.valueOf(Date.today().addDays(10));
            org_List.add(org_item);
            ORG.item = org_List;

            //*** LANG ****
            SAP_Product_DataModel.ZMM_TT_MAKT LANG = new SAP_Product_DataModel.ZMM_TT_MAKT();
            List<SAP_Product_DataModel.ZMM_S_MAKT> lang_List = new  List<SAP_Product_DataModel.ZMM_S_MAKT>();
            SAP_Product_DataModel.ZMM_S_MAKT langTR_item = new SAP_Product_DataModel.ZMM_S_MAKT();
            langTR_item.MATNR = '100';
            langTR_item.MAKTX = 'TEST TR';
            langTR_item.SPRAS = 'T';
            lang_List.add(langTR_item);
            SAP_Product_DataModel.ZMM_S_MAKT langRU_item = new SAP_Product_DataModel.ZMM_S_MAKT();
            langRU_item.MATNR = '100';
            langRU_item.MAKTX = 'TEST RU';
            langRU_item.SPRAS = 'R';
            lang_List.add(langRU_item);
            SAP_Product_DataModel.ZMM_S_MAKT langDE_item = new SAP_Product_DataModel.ZMM_S_MAKT();
            langDE_item.MATNR = '100';
            langDE_item.MAKTX = 'TEST DE';
            langDE_item.SPRAS = 'D';
            lang_List.add(langDE_item);
            SAP_Product_DataModel.ZMM_S_MAKT langENG_item = new SAP_Product_DataModel.ZMM_S_MAKT();
            langENG_item.MATNR = '100';
            langENG_item.MAKTX = 'TEST ENG';
            langENG_item.SPRAS = 'E';
            lang_List.add(langENG_item);
            LANG.item = lang_List;

            //*** UNIT ****
            SAP_Product_DataModel.ZMM_TT_MARM UNIT = new SAP_Product_DataModel.ZMM_TT_MARM();
            List<SAP_Product_DataModel.ZMM_S_MARM> unit_List = new  List<SAP_Product_DataModel.ZMM_S_MARM>();
            SAP_Product_DataModel.ZMM_S_MARM unit_item = new SAP_Product_DataModel.ZMM_S_MARM();
            unit_item.MATNR = '100';
            unit_List.add(unit_item);
            UNIT.item = unit_List;
            
            //*** PLANT ****
            SAP_Product_DataModel.ZMM_TT_MARC PLANT = new SAP_Product_DataModel.ZMM_TT_MARC();
            List<SAP_Product_DataModel.ZMM_S_MARC> plant_List = new  List<SAP_Product_DataModel.ZMM_S_MARC>();
            SAP_Product_DataModel.ZMM_S_MARC plant_item = new SAP_Product_DataModel.ZMM_S_MARC();
            plant_item.MATNR = '100';
            plant_List.add(plant_item);
            PLANT.item = plant_List;

            //*** VALUATION ****
            SAP_Product_DataModel.ZMM_TT_MBEW VALUATION = new SAP_Product_DataModel.ZMM_TT_MBEW();
            List<SAP_Product_DataModel.ZMM_S_MBEW> valuation_List = new  List<SAP_Product_DataModel.ZMM_S_MBEW>();
            SAP_Product_DataModel.ZMM_S_MBEW valuation_item = new SAP_Product_DataModel.ZMM_S_MBEW();
            valuation_item.MATNR = '100';
            valuation_List.add(valuation_item);
            VALUATION.item = valuation_List;
            
            //*** MEAN ****
            SAP_Product_DataModel.ZMM_TT_MEAN MEAN = new SAP_Product_DataModel.ZMM_TT_MEAN();
            List<SAP_Product_DataModel.ZMM_S_MEAN> mean_List = new  List<SAP_Product_DataModel.ZMM_S_MEAN>();
            SAP_Product_DataModel.ZMM_S_MEAN mean_item = new SAP_Product_DataModel.ZMM_S_MEAN();
            mean_item.MATNR = '100';
            mean_List.add(mean_item);
            MEAN.item = mean_List;
            
            //*** ET_PRODUCT ***
            SAP_Product_DataModel.ET_PRODUCT_element ET_PRODUCT = new SAP_Product_DataModel.ET_PRODUCT_element();
            List<SAP_Product_DataModel.ZMM_S_PRODUCT> etProduct_List = new List<SAP_Product_DataModel.ZMM_S_PRODUCT>();
            SAP_Product_DataModel.ZMM_S_PRODUCT etProduct_item = new SAP_Product_DataModel.ZMM_S_PRODUCT();
            etProduct_item.MATNR = '100';
            etProduct_item.ZZICRSERINO = '100';
            etProduct_item.ORG = ORG;
            etProduct_item.LANG = LANG;
            etProduct_item.UNIT = UNIT;
            etProduct_item.PLANT = PLANT;
            etProduct_item.VALUATION = VALUATION;
            etProduct_item.MEAN = MEAN;
            etProduct_item.MEINS = 'ST';
            etProduct_List.add(etProduct_item);
            ET_PRODUCT.item = etProduct_List;
            
            //*** ET_SIZE ****
            SAP_Product_DataModel.ET_SIZE_element ET_SIZE = new SAP_Product_DataModel.ET_SIZE_element();
            List<SAP_Product_DataModel.ZMM_SF_S_SIZE> etSize_List = new List<SAP_Product_DataModel.ZMM_SF_S_SIZE>();
            SAP_Product_DataModel.ZMM_SF_S_SIZE etSize_item = new SAP_Product_DataModel.ZMM_SF_S_SIZE();
            etSize_item.SIZE = 1;
            etSize_List.add(etSize_item);
            ET_SIZE.item = etSize_List;

            //*** RESPONSE_X ***
            response_x.ET_INDEX = ET_INDEX;
            response_x.ET_MESS = ET_MESS;
            response_x.ET_PRODUCT = ET_PRODUCT;
            response_x.ET_SIZE = ET_SIZE;

            response.put('response_x', response_x);
        }
}