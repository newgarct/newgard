

WITH stg_ar_dbcrmhdr_tbl 
     AS (--get debit/credit memo header info --  
        SELECT gl_cmp_key,in_brnch_key,ar_dbcrm_type,ar_dbcrm_key,tran_date_key,comp_date_key,ar_bill_key,ar_dbcrm_amt,
               ar_ship_key 
         FROM   erp_int_sub.dbo.ar_dbcrmhdr_tbl), 
     stg_ar_dbcrm_tbl --  
     AS (--get debit/credit memo DETEAIL info  
        SELECT MEMO_DTL.gl_cmp_key,MEMO_DTL.in_brnch_key,MEMO_DTL.ar_dbcrm_type,MEMO_DTL.ar_dbcrm_key,ar_dbcrdtl_key,
               so_prod_key, 
               so_dtl_key,ar_dbcrm_afill,en_uom_afill,ar_dbcrm_skuqty,ar_dbcrm_skuuom,so_ship_date,MEMO_DTL.ar_ship_key
         FROM   erp_int_sub.dbo.ar_dbcrm_tbl MEMO_DTL 
        --INNER JOIN stg_ar_dbcrmhdr_tbl MEMO_HDR  
        --        ON MEMO_HDR.gl_cmp_key = MEMO_DTL.gl_cmp_key  
        --           AND MEMO_HDR.in_brnch_key = MEMO_DTL.in_brnch_key  
        --           AND MEMO_HDR.ar_dbcrm_type = MEMO_DTL.ar_dbcrm_type  
        --           AND MEMO_HDR.ar_dbcrm_key = MEMO_DTL.ar_dbcrm_key  
        --           AND MEMO_HDR.ar_dbcrm_type = MEMO_DTL.ar_dbcrm_type 
        ), 
     stg_ar_dcmadj_tbl --  
     AS (--get debit/credit adjusted memo info  
        SELECT DISTINCT gl_cmp_key,so_brnch_key,ar_dbcrm_type,ar_dbcrm_key,ar_dbcrdtl_key,ar_dcmadj_keytyp,
                        ar_dcmadj_examtc 
         FROM   erp_int_sub.dbo.ar_dcmadj_tbl 
        --WHERE  ar_dcmadj_keytyp = 1 --ar_dcmadj_keytyp: Adjustment/Promotion (0 = price adjustment, 1 = N/A)  
        ), 
     stg_so_rtdtl_tbl --  
     AS (--get sales return detail info  
        SELECT SRO.gl_cmp_key,so_brnch_key,so_rthdr_key,so_rtdtl_key,so_prod_key,SRO.ar_dbcrm_type,so_rtdtl_rmaqty
               --AS return_order_quantity  
               ,so_rtdtl_rmauom --AS order_uom_code  
               ,so_resn_code,so_hdr_key,SRO.so_dtl_key,so_rtdtl_skuqty --AS return_stock_order_quantity  
               ,so_rtdtl_skuuom --AS order_stock_uom_code --use so_dtl_tbl.in_prd_uom for nulls  
               ,so_rtdtl_whstoretu,in_lot_key,so_dtl_sltyp-- AS sales_type_code  
               ,SRO.ar_dbcrm_key,so_rtdtl_crmoamt,so_rtdtl_rtfllqty-- AS return_order_fill_quantity  
               ,SRO.ar_dbcrdtl_key,en_uom_filluom 
         FROM   erp_int_sub.dbo.so_rtdtl_tbl SRO), 
     stg_so_rthdr_tbl --CN Can Remove  
     AS (--get sales return header info  
        SELECT DISTINCT SRH.gl_cmp_key,SRH.so_brnch_key,SRH.so_rthdr_key,so_rthdr_rtdt,en_cust_key,ar_bill_key
                        --,SRH.so_resn_code  
                        ,SRH.so_hdr_key,ar_ship_key,gl_crncy_key --not in original mapping, but may be useful  
         FROM   erp_int_sub.dbo.so_rthdr_tbl SRH 
        --INNER JOIN stg_so_rtdtl_tbl SRD  
        --        ON SRD.gl_cmp_key = SRH.gl_cmp_key  
        --           AND SRD.so_brnch_key = SRH.so_brnch_key  
        --           AND SRD.so_rthdr_key = SRH.so_rthdr_key --where so_rthdr_rtdt > '12/31/2014 11:59:59 PM'  
        ), 
     stg_so_brprd_tbl --CN Can Remove  
     AS (--get branch product info  
        SELECT DISTINCT SBP.gl_cmp_key,so_brnch_key,SBP.so_prod_key,so_brprd_sales --used to drive gl_acct_key  
                        ,so_brprd_serv 
         FROM   erp_int_sub.dbo.so_brprd_tbl SBP 
        --INNER JOIN stg_ar_dbcrm_tbl DCH  
        --        ON DCH.gl_cmp_key = SBP.gl_cmp_key  
        --           AND DCH.in_brnch_key = SBP.so_brnch_key  
        --           AND DCH.so_prod_key = SBP.so_prod_key 
        ), 
     stg_so_prod_tbl 
     AS (--get product info --CN Can Remove  
        SELECT DISTINCT PRD.gl_cmp_key,PRD.so_prod_key,so_prod_desc --,in_item_key --could have value  
                        ,so_prod_shipf 
         FROM   erp_int_sub.dbo.so_prod_tbl PRD 
                INNER JOIN stg_ar_dbcrm_tbl DCH 
                        ON DCH.gl_cmp_key = PRD.gl_cmp_key 
                           AND DCH.so_prod_key = PRD.so_prod_key), 
     stg_en_sltyp_tbl 
     AS (--get sales type info --CN Can Remove  
        SELECT en_sltyp_key,en_sltyp_desc,en_sltyp_glid 
         FROM   erp_int_sub.dbo.en_sltyp_tbl), 
     stg_en_bill_tbl --  
     AS (SELECT --get enterprose bill to  
        en_bill_key,en_cust_key 
         FROM   erp_int_sub.dbo.en_bill_tbl) 
--,stg_ar_dbcrm_tbl_agg  
--AS (SELECT MDTL.gl_cmp_key  
--           ,MDTL.in_brnch_key  
--           ,MDTL.ar_dbcrm_type  
--           ,MDTL.ar_dbcrm_key  
--           ,MADJ.ar_dcmadj_keytyp --1  
--           ,Sum(Isnull(MADJ.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc  
--           ,Sum(MDTL.ar_dbcrm_skuqty)                    AS total_memo_stock_quantity  
--           ,Sum(MDTL.ar_dbcrm_afill)                     AS total_memo_fill_quantity  
--           ,Max(MDTL.en_uom_afill)                       AS memo_fill_uom_code  
--           ,Max(MDTL.ar_dbcrm_skuuom)                    AS memo_stock_uom_code  
--    FROM   stg_ar_dbcrm_tbl MDTL  
--           LEFT OUTER JOIN stg_ar_dcmadj_tbl MADJ  
--                        ON MDTL.gl_cmp_key = MADJ.gl_cmp_key  
--                           AND MDTL.in_brnch_key = MADJ.so_brnch_key  
--                           AND MDTL.ar_dbcrm_type = MADJ.ar_dbcrm_type  
--                           AND MDTL.ar_dbcrm_key = MADJ.ar_dbcrm_key  
--                           AND MDTL.ar_dbcrdtl_key = MADJ.ar_dbcrdtl_key  
--    WHERE  MADJ.ar_dcmadj_keytyp = 1 --ar_dcmadj_keytyp: Adjustment/Promotion (0 = price adjustment, 1 = N/A)  
--    GROUP  BY MDTL.gl_cmp_key  
--              ,MDTL.in_brnch_key  
--              ,MDTL.ar_dbcrm_type --C  
--              ,MDTL.ar_dbcrm_key  
--              ,MADJ.ar_dcmadj_keytyp) 
--,stg_en_prod_tbl  
--AS (--get product description--CN Not Used  
--   SELECT --distinct  
--   en_prod_key  
--   ,en_prod_desc  
--   ,Cast(en_item_key + CASE WHEN im_pack_key <> '' THEN '-' + im_pack_key ELSE '' END AS VARCHAR(40)) AS  
--    material_id  
--    FROM   erp_int_sub.dbo.en_prod_tbl prd --inner join STG_SO_DTL_TBL sod on  
--   )  
, 
     stg_so_hdr_tbl 
     AS (SELECT so_hdr_key,gl_cmp_key,so_brnch_key,en_cust_key 
         FROM   erp_int_sub.dbo.so_hdr_tbl), 
     stg_so_dtl_tbl 
     AS (SELECT so_hdr_key,so_dtl_key,gl_cmp_key,so_brnch_key,in_prod_uom,so_dtl_shpws,ar_ship_key
         FROM   erp_int_sub.dbo.so_dtl_tbl i) 
--,stg_ar_dbcrm_adj_agg  
--AS (SELECT aa.gl_cmp_key  
--           ,aa.in_brnch_key  
--           ,aa.ar_dbcrm_key  
--           ,aa.so_prod_key  
--           ,Sum(Isnull(bb.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc  
--    FROM   stg_ar_dbcrm_tbl aa --Debit/Credit Memo Detail  
--           LEFT OUTER JOIN stg_ar_dcmadj_tbl bb  
--                        ON aa.gl_cmp_key = bb.gl_cmp_key  
--                           AND aa.in_brnch_key = bb.so_brnch_key  
--                           AND aa.ar_dbcrm_type = bb.ar_dbcrm_type  
--                           AND aa.ar_dbcrm_key = bb.ar_dbcrm_key  
--                           AND aa.ar_dbcrdtl_key = bb.ar_dbcrdtl_key  
--                           AND bb.ar_dcmadj_keytyp = 1  
--    --ar_dcmadj_keytyp: Adjustment/Promotion (0 = price adjustment, 1 = N/A)  
--    WHERE  aa.ar_dbcrm_type = 'C' --Credit  
--    GROUP  BY aa.gl_cmp_key  
--              ,aa.in_brnch_key  
--              ,aa.ar_dbcrm_key  
--              ,aa.so_prod_key)  
, 
     stg_gl_interface_tbl 
     AS (--get general ledger interface info-- 
        SELECT gli.gl_subpost_key,gli.gl_interface_seqno,gli.gl_cmp_key,gli.gl_interface_date,gli.gl_interface_srce
               ,gli.gl_interface_docty,gli.gl_interface_entid,gl_interface_ref2,gli.gl_acct_key,gl_interface_crtdt
               ,gli.gl_interface_cramt 
               ,gli.gl_interface_dbamt,gli.gl_interface_docno,gli.sa_user_key,gli.gl_tran_key,gli.gl_interface_desc
               ,gli.gl_interface_postf 
               ,gli.gl_perod_seqno,so_prod_key,gl_intface_origent,gl_cmp_orig,gl_intface_origdoc,gl_interface_ref3
         FROM   erp_int_sub.dbo.gl_interface_tbl gli 
        --WHERE  
        --  gli.gl_interface_srce = 'AR' and 
        --  gl_interface_docty in ('c','d') --for memo 
        ), 
     stg_gl_appcd_tbl 
     AS (SELECT gl_appcd_key,gl_appcd_desc 
         FROM   erp_int_sub.dbo.gl_appcd_tbl gla), 
     stg_gl_appdoc_tbl 
     AS (SELECT gl_appdoc_key,gl_appcd_key,gl_appdoc_desc 
         FROM   erp_int_sub.dbo.gl_appdoc_tbl gl), 
     stg_en_ship_tbl 
     AS (SELECT en_ship_key,en_cust_key 
         FROM   erp_int_sub.dbo.en_ship_tbl) 
/****************************************************************************************************/
, 
     stg_cr_memo_wo_rma 
     AS (SELECT 1 AS type,--Credit Memo without RMA detail tie   
                a.gl_cmp_key,a.in_brnch_key,a.ar_dbcrm_type,a.ar_dbcrm_key,c.ar_dbcrdtl_key, 
                --Deriving the gl_account_key   
                CASE 
                  WHEN f.so_prod_shipf = 1 --shippable product flag   
                THEN Replace(e.so_brprd_sales, '@@', Isnull(g.en_sltyp_glid, '00')) 
                  --if it is a shippable product then use the Branch Product Sales Account   
                  ELSE Replace(e.so_brprd_serv, '@@', Isnull(g.en_sltyp_glid, '00')) 
                --if it is not a shippable product then use the Branch Product Service Account   
                END AS gl_acct_key,c.so_rtdtl_key,c.so_rthdr_key,c.so_hdr_key,c.so_dtl_key, 
                b.so_prod_key AS adage_product_key 
                   ,c.in_lot_key,c.so_dtl_sltyp,c.so_resn_code,c.so_rtdtl_rmaqty, 
                Round(c.so_rtdtl_crmoamt, 2) AS so_rtdtl_crmoamt 
                   ,b.ar_dcmadj_examtc,d.en_cust_key,c.so_rtdtl_rmaqty AS return_order_quantity,
                c.so_rtdtl_rmauom AS order_uom_code 
                   ,c.so_rtdtl_skuqty AS return_stock_order_quantity, 
                --c.so_rtdtl_skuuom as order_stock_uom_code,   
                CASE 
                  WHEN c.so_rtdtl_skuuom = '' THEN i.in_prod_uom 
                  ELSE c.so_rtdtl_skuuom 
                END AS order_stock_uom_code,c.so_rtdtl_rtfllqty AS return_order_fill_quantity,
                   c.en_uom_filluom AS order_fill_uom_code,NULL AS memo_stock_quantity,NULL AS memo_stock_uom_code,NULL
                AS 
                   memo_fill_quantity,NULL AS memo_fill_uom_code,c.so_dtl_sltyp AS sales_type_code,
                   h.en_cust_key AS adage_billing_customer_code,c.so_rtdtl_whstoretu, 
                --Numbering by return detail credit amount for subsequent adjustment allocation to the detail line with greatest amount:
                Row_number() 
                  OVER ( 
                    partition BY a.gl_cmp_key, a.in_brnch_key, a.ar_dbcrm_type, a.ar_dbcrm_key, b.so_prod_key
                    ORDER BY c.so_rtdtl_crmoamt) AS row_count 
         --INTO   #sales_return_detail_source  
         FROM   stg_ar_dbcrmhdr_tbl a --Debit/Credit Memo Header   
                INNER JOIN 
                --Adjustment amount for credits only. Aggregated up to header level from the detail level.   
                (SELECT aa.gl_cmp_key,aa.in_brnch_key,aa.ar_dbcrm_key,aa.so_prod_key, 
                        Sum(Isnull(bb.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc 
                 FROM   stg_ar_dbcrm_tbl aa --Debit/Credit Memo Detail   
                        LEFT OUTER JOIN stg_ar_dcmadj_tbl bb 
                                     ON aa.gl_cmp_key = bb.gl_cmp_key 
                                        AND aa.in_brnch_key = bb.so_brnch_key 
                                        AND aa.ar_dbcrm_type = bb.ar_dbcrm_type 
                                        AND aa.ar_dbcrm_key = bb.ar_dbcrm_key 
                                        AND aa.ar_dbcrdtl_key = bb.ar_dbcrdtl_key 
                                        AND bb.ar_dcmadj_keytyp = 1 
                 --ar_dcmadj_keytyp: Adjustment/Promotion (0 = price adjustment, 1 = N/A)    
                 WHERE  aa.ar_dbcrm_type = 'C' --Credit   
                 GROUP  BY aa.gl_cmp_key,aa.in_brnch_key,aa.ar_dbcrm_key,aa.so_prod_key) b 
                        ON a.gl_cmp_key = b.gl_cmp_key 
                           AND a.in_brnch_key = b.in_brnch_key 
                           AND a.ar_dbcrm_type = 'C' 
                           AND a.ar_dbcrm_key = b.ar_dbcrm_key 
                LEFT OUTER JOIN stg_so_rtdtl_tbl c --Sales Order Return (RMA) Detail   
                             ON c.ar_dbcrdtl_key IS NULL 
                                AND b.gl_cmp_key = c.gl_cmp_key 
                                AND b.in_brnch_key = c.so_brnch_key 
                                AND b.ar_dbcrm_key = c.ar_dbcrm_key 
                                AND b.so_prod_key = c.so_prod_key 
                LEFT OUTER JOIN stg_so_rthdr_tbl d --Sales Order Return (RMA) Header   
                             ON c.gl_cmp_key = d.gl_cmp_key 
                                AND c.so_brnch_key = d.so_brnch_key 
                                AND c.so_rthdr_key = d.so_rthdr_key 
                INNER JOIN stg_so_brprd_tbl e --Branch-Product   
                        ON b.gl_cmp_key = e.gl_cmp_key 
                           AND b.in_brnch_key = e.so_brnch_key 
                           AND b.so_prod_key = e.so_prod_key 
                INNER JOIN stg_so_prod_tbl f --Product   
                        ON b.gl_cmp_key = f.gl_cmp_key 
                           AND b.so_prod_key = f.so_prod_key 
                LEFT OUTER JOIN stg_en_sltyp_tbl g --Sales Type Detail   
                             ON c.so_dtl_sltyp = g.en_sltyp_key 
                LEFT OUTER JOIN stg_en_bill_tbl h--Enterprise Bill To   
                             ON d.ar_bill_key = h.en_bill_key 
                LEFT OUTER JOIN stg_so_dtl_tbl i 
                             ON c.so_hdr_key = i.so_hdr_key 
                                AND c.so_dtl_key = i.so_dtl_key 
                                AND c.gl_cmp_key = i.gl_cmp_key 
                                AND c.so_brnch_key = i.so_brnch_key 
         --where there is no tie to RMA detail   
         WHERE  EXISTS (SELECT 1 
                        FROM   stg_so_rtdtl_tbl h 
                        WHERE  h.ar_dbcrdtl_key IS NULL 
                           AND b.gl_cmp_key = h.gl_cmp_key 
                           AND b.in_brnch_key = h.so_brnch_key 
                           AND b.ar_dbcrm_key = h.ar_dbcrm_key)), 
     stg_cr_memo_w_rma 
     AS (SELECT 2 AS type,--Credit Memo with RMA detail tie   
                a.gl_cmp_key,a.in_brnch_key,a.ar_dbcrm_type,a.ar_dbcrm_key,b.ar_dbcrdtl_key, 
                --Deriving the gl_account_key   
                CASE 
                  WHEN f.so_prod_shipf = 1 --shippable product flag   
                THEN Replace(e.so_brprd_sales, '@@', Isnull(g.en_sltyp_glid, '00')) 
                  --if it is a shippable product then use the Branch Product Sales Account   
                  ELSE Replace(e.so_brprd_serv, '@@', Isnull(g.en_sltyp_glid, '00')) 
                --if it is not a shippable product then use the Branch Product Service Account   
                END AS gl_acct_key,c.so_rtdtl_key,c.so_rthdr_key,c.so_hdr_key,c.so_dtl_key, 
                b.so_prod_key AS adage_product_key 
                   ,c.in_lot_key,c.so_dtl_sltyp,c.so_resn_code,c.so_rtdtl_rmaqty, 
                Round(c.so_rtdtl_crmoamt, 2) AS so_rtdtl_crmoamt 
                   ,Isnull(h.ar_dcmadj_examtc, 0.0) AS ar_dcmadj_examtc,d.en_cust_key, 
                c.so_rtdtl_rmaqty AS return_order_quantity, 
                   c.so_rtdtl_rmauom AS order_uom_code,c.so_rtdtl_skuqty AS return_stock_order_quantity,CASE
                           WHEN c.so_rtdtl_skuuom = '' THEN j.in_prod_uom 
                           ELSE c.so_rtdtl_skuuom 
                           END AS order_stock_uom_code,c.so_rtdtl_rtfllqty AS return_order_fill_quantity,
                   c.en_uom_filluom AS order_fill_uom_code,b.ar_dbcrm_skuqty AS memo_stock_quantity,
                   b.ar_dbcrm_skuuom AS memo_stock_uom_code,b.ar_dbcrm_afill AS memo_fill_quantity,
                   b.en_uom_afill AS memo_fill_uom_code,c.so_dtl_sltyp AS sales_type_code, 
                   i.en_cust_key AS adage_billing_customer_code,c.so_rtdtl_whstoretu, 
                --Numbering by return detail credit amount for subsequent adjustment allocation to the detail line with greatest amount:
                Row_number() 
                  OVER ( 
                    partition BY a.gl_cmp_key, a.in_brnch_key, a.ar_dbcrm_type, a.ar_dbcrm_key, b.ar_dbcrdtl_key
                    ORDER BY c.so_rtdtl_crmoamt) AS row_count 
         FROM   stg_ar_dbcrmhdr_tbl a --Debit/Credit Memo Header   
                INNER JOIN stg_ar_dbcrm_tbl b --Debit/Credit Memo Detail   
                        ON a.gl_cmp_key = b.gl_cmp_key 
                           AND a.in_brnch_key = b.in_brnch_key 
                           AND a.ar_dbcrm_type = b.ar_dbcrm_type 
                           AND a.ar_dbcrm_key = b.ar_dbcrm_key 
                INNER JOIN stg_so_rtdtl_tbl c --Sales Order Return (RMA) Detail   
                        ON a.gl_cmp_key = c.gl_cmp_key 
                           AND a.in_brnch_key = c.so_brnch_key 
                           AND a.ar_dbcrm_type = 'C' 
                           AND a.ar_dbcrm_key = c.ar_dbcrm_key 
                           AND b.ar_dbcrdtl_key = c.ar_dbcrdtl_key 
                INNER JOIN stg_so_rthdr_tbl d --Sales Order Return (RMA) Header   
                        ON c.gl_cmp_key = d.gl_cmp_key 
                           AND c.so_brnch_key = d.so_brnch_key 
                           AND c.so_rthdr_key = d.so_rthdr_key 
                INNER JOIN stg_so_brprd_tbl e --Branch-Product   
                        ON b.gl_cmp_key = e.gl_cmp_key 
                           AND b.in_brnch_key = e.so_brnch_key 
                           AND b.so_prod_key = e.so_prod_key 
                INNER JOIN stg_so_prod_tbl f --Product   
                        ON b.gl_cmp_key = f.gl_cmp_key 
                           AND b.so_prod_key = f.so_prod_key 
                LEFT OUTER JOIN stg_en_sltyp_tbl g --Sales Type   
                             ON c.so_dtl_sltyp = g.en_sltyp_key 
                LEFT OUTER JOIN 
                --Adjustment amount for credits and applicable adjustment type only. Aggregated up from the detail level.
                (SELECT aa.gl_cmp_key,aa.so_brnch_key,aa.ar_dbcrm_type,aa.ar_dbcrm_key,aa.ar_dbcrdtl_key,Sum(
                        Isnull(aa.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc 
                 FROM   stg_ar_dcmadj_tbl aa 
                 WHERE  aa.ar_dbcrm_type = 'C' --Credits only   
                    AND aa.ar_dcmadj_keytyp = 1 --Applicable adjustment type only   
                 GROUP  BY aa.gl_cmp_key,aa.so_brnch_key,aa.ar_dbcrm_type,aa.ar_dbcrm_key,aa.ar_dbcrdtl_key) h
                             ON b.gl_cmp_key = h.gl_cmp_key 
                                AND b.in_brnch_key = h.so_brnch_key 
                                AND b.ar_dbcrm_type = h.ar_dbcrm_type 
                                AND b.ar_dbcrm_key = h.ar_dbcrm_key 
                                AND b.ar_dbcrdtl_key = h.ar_dbcrdtl_key 
                LEFT OUTER JOIN stg_en_bill_tbl i--Enterprise Bill To   
                             ON d.ar_bill_key = i.en_bill_key 
                LEFT OUTER JOIN stg_so_dtl_tbl j 
                             ON c.so_hdr_key = j.so_hdr_key 
                                AND c.so_dtl_key = j.so_dtl_key 
                                AND c.gl_cmp_key = j.gl_cmp_key 
                                AND c.so_brnch_key = j.so_brnch_key) 
/******************************************************************************************  
******************************************************************************************/ 
, 
     stg_sls_rtn_dtl_src 
     AS (SELECT * 
         FROM   stg_cr_memo_wo_rma 
         UNION ALL 
         SELECT * 
         FROM   stg_cr_memo_w_rma), 
     stg_adj_allc 
     AS ( 
        --Perform initial allocation of Credit Memo Adjustment dollars to RMA Detail (AKA Lot) level. 
        --RMA Detail Credit Amount forms the basis for determining the spread of the adjustment dollars.
        --Note: ISNULLs required on join (on-clause) of ar_dbcrdtl_key to avoid fallout.   
        SELECT a.*, 
               --Case statement below remedies divide by zero risk   
               Round(a.ar_dcmadj_examtc * CASE 
                                            WHEN a.so_rtdtl_crmoamt = 0.0 THEN 1.0 
                                            ELSE a.so_rtdtl_crmoamt 
                                          END / CASE 
                                                  WHEN b.total_credit = 0.0 THEN 1.0 
                                                  ELSE Isnull(b.total_credit, 1.0) 
                                                END, 2) AS allocated_adjustment,b.total_credit,b.max_row_count
         FROM   stg_sls_rtn_dtl_src a 
                LEFT OUTER JOIN 
                --Roll up of the detail level data to a header-level total credit amount   
                (SELECT aa.gl_cmp_key,aa.in_brnch_key,aa.ar_dbcrm_type,aa.ar_dbcrm_key,aa.ar_dbcrdtl_key
                        ,aa.adage_product_key 
                        ,aa.ar_dcmadj_examtc,Max(aa.row_count) AS max_row_count,Sum(aa.so_rtdtl_crmoamt) AS total_credit
                 FROM   stg_sls_rtn_dtl_src aa 
                 GROUP  BY aa.gl_cmp_key,aa.in_brnch_key,aa.ar_dbcrm_type,aa.ar_dbcrm_key,aa.ar_dbcrdtl_key
                ,aa.adage_product_key 
                ,aa.ar_dcmadj_examtc) b 
                             ON a.gl_cmp_key = b.gl_cmp_key 
                                AND a.in_brnch_key = b.in_brnch_key 
                                AND a.ar_dbcrm_type = b.ar_dbcrm_type 
                                AND a.ar_dbcrm_key = b.ar_dbcrm_key 
                                AND Isnull(a.ar_dbcrdtl_key, '') = Isnull(b.ar_dbcrdtl_key, '')
                                AND a.adage_product_key = b.adage_product_key), 
     stg_rnd_adj_allc 
     AS ( 
        --Ensure no fallout of cents by making rounding adjustments to the highest value credit amount for a Credit Memo Detail.
        SELECT a.*,CASE 
                     WHEN Round(a.ar_dcmadj_examtc, 2) <> Round(b.total_allocated_adjustment, 2)
                          AND a.row_count = a.max_row_count THEN 
                     a.allocated_adjustment 
                     + Round(a.ar_dcmadj_examtc, 2) - Round(b.total_allocated_adjustment, 2 
                                                      ) 
                     ELSE a.allocated_adjustment 
                   END AS rounded_allocated_adjustment 
         FROM   stg_adj_allc a 
                LEFT OUTER JOIN 
                --Roll up of the detail level data to a header-level total allocated adjustment amount 
                (SELECT aa.gl_cmp_key,aa.in_brnch_key,aa.ar_dbcrm_type,aa.ar_dbcrm_key,aa.ar_dbcrdtl_key
                        ,aa.adage_product_key 
                        , 
                        Round(Sum(aa.allocated_adjustment), 2) AS 
                        total_allocated_adjustment 
                 FROM   stg_adj_allc aa 
                 GROUP  BY aa.gl_cmp_key,aa.in_brnch_key,aa.ar_dbcrm_type,aa.ar_dbcrm_key,aa.ar_dbcrdtl_key
                ,aa.adage_product_key) b 
                             ON a.gl_cmp_key = b.gl_cmp_key 
                                AND a.in_brnch_key = b.in_brnch_key 
                                AND a.ar_dbcrm_type = b.ar_dbcrm_type 
                                AND a.ar_dbcrm_key = b.ar_dbcrm_key 
                                AND Isnull(a.ar_dbcrdtl_key, '') = Isnull(b.ar_dbcrdtl_key, '')
                                AND a.adage_product_key = b.adage_product_key), 
     stg_sls_rtn_gl_src 
     AS (SELECT Cast(a.gl_subpost_key AS VARCHAR(10)) 
                + '-' 
                + Cast(a.gl_interface_seqno AS VARCHAR(10)) AS system_of_record_natural_id, 
                --Concatenated system of record natural ID   
                CASE 
                  WHEN a.gl_interface_dbamt != 0.0 THEN 'debit' 
                  ELSE 'credit' 
                END AS accounting_transaction_amount_type_name, 
                a.gl_interface_desc AS accounting_transaction_detail_description, 
                   a.gl_interface_date AS accounting_transaction_datetime,a.gl_interface_crtdt AS source_entry_datetime,
                CASE 
                           WHEN a.gl_interface_dbamt != 0.0 THEN a.gl_interface_dbamt 
                           ELSE a.gl_interface_cramt 
                           END AS accounting_transaction_dollar_amount,CASE 
                                                                         WHEN gl_interface_postf = 1 THEN 'Y'
                                                                         ELSE 'N' 
                                                                       END AS posted_flag, 
                a.sa_user_key AS adage_update_user_id, 
                   a.gl_tran_key AS adage_transaction_group_number,a.gl_cmp_key AS adage_company_number,
                   a.gl_subpost_key AS adage_subpost_number, 
                a.gl_interface_seqno AS adage_accounting_transaction_sequence 
                   ,b.[type],b.so_rtdtl_crmoamt,b.rounded_allocated_adjustment,b.so_resn_code, 
                a.gl_interface_srce AS adage_source_code 
                   ,a.gl_interface_docty AS adage_document_type_code,e.gl_appcd_desc AS adage_source_name,
                   f.gl_appdoc_desc AS adage_document_type_name,a.gl_intface_origent AS adage_branch_number
                ,b.so_rtdtl_key 
                   ,b.so_rthdr_key,b.return_order_quantity,b.order_uom_code,b.return_stock_order_quantity
                ,b.order_stock_uom_code 
                   ,b.return_order_fill_quantity,b.order_fill_uom_code,b.memo_stock_quantity,b.memo_stock_uom_code
                ,b.memo_fill_quantity,b.memo_fill_uom_code 
                   ,b.sales_type_code,b.adage_billing_customer_code,b.adage_product_key, 
                   h.en_cust_key AS adage_ordering_customer_id,i.en_cust_key AS adage_receiving_customer_id
                ,g.so_dtl_shpws 
                   ,b.so_rtdtl_whstoretu,h.so_hdr_key AS adage_sales_order_number, 
                g. so_dtl_key AS adage_sales_order_detail_sequence,a.gl_cmp_key 
                   ,a.gl_acct_key, 
                --Numbering by return detail credit amount for subsequent adjustment allocation to the detail line with greatest amount:
                Row_number() 
                  OVER ( 
                    partition BY a.gl_subpost_key, a.gl_interface_seqno 
                    ORDER BY b.so_rtdtl_crmoamt + b.rounded_allocated_adjustment) AS gl_row_count
         --INTO   #sales_return_gl_source  
         FROM   stg_gl_interface_tbl a 
                LEFT OUTER JOIN stg_rnd_adj_allc b 
                             ON a.gl_cmp_key = b.gl_cmp_key 
                                AND a.gl_interface_entid = b.in_brnch_key 
                                AND a.gl_interface_docty = b.ar_dbcrm_type 
                                AND a.gl_interface_docno = b.ar_dbcrm_key 
                                AND a.gl_acct_key = b.gl_acct_key 
                LEFT OUTER JOIN (SELECT DISTINCT aa.gl_cmp_key,aa.so_brnch_key,aa.ar_dbcrm_key,aa.so_rthdr_key
                                 FROM   stg_so_rtdtl_tbl aa) c 
                             ON a.gl_cmp_key = c.gl_cmp_key 
                                AND a.gl_interface_entid = c.so_brnch_key 
                                AND a.gl_interface_docty = 'C' --Credit   
                                AND a.gl_interface_docno = c.ar_dbcrm_key 
                LEFT OUTER JOIN stg_so_rthdr_tbl d 
                             ON c.gl_cmp_key = d.gl_cmp_key 
                                AND c.so_brnch_key = d.so_brnch_key 
                                AND c.so_rthdr_key = d.so_rthdr_key 
                LEFT OUTER JOIN stg_gl_appcd_tbl e 
                             ON a.gl_interface_srce = e.gl_appcd_key 
                LEFT OUTER JOIN stg_gl_appdoc_tbl f 
                             ON a.gl_interface_srce = f.gl_appcd_key 
                                AND a.gl_interface_docty = f.gl_appdoc_key 
                LEFT OUTER JOIN stg_so_dtl_tbl g --Sales Order Detail Table   
                             ON b.so_hdr_key = g.so_hdr_key 
                                AND b.so_dtl_key = g.so_dtl_key 
                                AND b.gl_cmp_key = g.gl_cmp_key 
                                AND b.in_brnch_key = g.so_brnch_key 
                LEFT OUTER JOIN stg_so_hdr_tbl h --Sales Order Header Table   
                             ON g.so_hdr_key = h.so_hdr_key 
                                AND g.gl_cmp_key = h.gl_cmp_key 
                                AND g.so_brnch_key = h.so_brnch_key 
                LEFT OUTER JOIN stg_en_ship_tbl i 
                             ON g.ar_ship_key = i.en_ship_key 
         WHERE  a.gl_interface_srce = 'AR' --Accounts Receivable   
            AND EXISTS --Limits GL transactions to only RMA-related Credit Memos   
                (SELECT 1 
                 FROM   stg_rnd_adj_allc c 
                 WHERE  a.gl_cmp_key = c.gl_cmp_key 
                    AND a.gl_interface_entid = c.in_brnch_key 
                    AND a.gl_interface_docty = c.ar_dbcrm_type 
                    AND a.gl_interface_docno = c.ar_dbcrm_key)) 
--CN: RETURNS 96 BUT SOURCE RETURNS 79 
, 
     stg_rmv_dtl_gl_src 
     AS ( 
        --Figure out which GL Credit Memo transaction amounts vary greater than .5% (our business rule value to determine round adjustments or RMA Detail fallout) from the newly caluculated credit amounts at an RMA Detail level.
        --Max GL row number determined to help identify the row to apply rounding adjustments.   
        SELECT system_of_record_natural_id,Round(Sum(so_rtdtl_crmoamt 
                                                     + rounded_allocated_adjustment), 2) AS 
                                                  calculated_accounting_transaction_dollar_amount,
               Round(Min(accounting_transaction_dollar_amount), 2) - 
                      Round(Sum(so_rtdtl_crmoamt 
                                + rounded_allocated_adjustment), 2) AS difference_transaction_dollar_amount,
               Max(gl_row_count) AS max_gl_row_count 
         --INTO   #remove_detail_gl_source  
         --FROM   #sales_return_gl_source  
         FROM   stg_sls_rtn_gl_src 
         WHERE  [type] IS NOT NULL 
         GROUP  BY system_of_record_natural_id 
         HAVING Round(Min(accounting_transaction_dollar_amount), 2) <> Round(Sum(so_rtdtl_crmoamt
                                                                                 + rounded_allocated_adjustment), 2)
                --when there is a difference between the rounded amounts...   
                AND Abs(Round(Min(accounting_transaction_dollar_amount), 2) - 
                        Round(Sum(so_rtdtl_crmoamt 
                                  + rounded_allocated_adjustment), 2)) 
                    / 
                        Round(Min(accounting_transaction_dollar_amount), 2) >= 0.005 
        --...and the difference between two amounts is greater than or equal to 0.5%   
        ) 
--,STG_SLS_RTN_ORD_ACCT_TRNS AS( 
--CN took 1:24 78907 vs 1:30 78890 
--Carry detail forward for non-revenue GL transactions related to the Credit Memo setting a "new" rounded_gl_amount equal to transaction amount (no change).
SELECT system_of_record_natural_id + '_' 
       + Cast(Isnull(so_rtdtl_key, 0) AS VARCHAR(255)) AS system_of_record_natural_id,adage_company_number,
       accounting_transaction_datetime,Isnull(so_resn_code, 'Unspecific') AS so_resn_code,adage_source_code,
       adage_document_type_name,adage_branch_number,adage_accounting_transaction_sequence, 
       Isnull(so_rtdtl_key, 0) AS so_rtdtl_key,Isnull(so_rthdr_key, 0) AS so_rthdr_key, 
       Isnull(return_order_quantity, 0) AS return_order_quantity,Isnull(order_uom_code, '0') AS order_uom_code,Isnull(
       return_stock_order_quantity, 0) AS return_stock_order_quantity, 
       Isnull(order_stock_uom_code, '0') AS order_stock_uom_code, 
       Isnull(return_order_fill_quantity, 0) AS return_order_fill_quantity, 
       Isnull(order_fill_uom_code, '0') AS order_fill_uom_code,Isnull(memo_stock_quantity, 0) AS memo_stock_quantity,
       Isnull(memo_stock_uom_code, '0') AS memo_stock_uom_code,Isnull(memo_fill_quantity, 0) AS memo_fill_quantity,
       Isnull(memo_fill_uom_code, '0') AS memo_fill_uom_code,Isnull(sales_type_code, 'Unspecific') AS sales_type_code,
       Isnull(adage_billing_customer_code, 0) AS adage_billing_customer_code, 
       Isnull(adage_product_key, 0) AS adage_product_key,Isnull(so_dtl_shpws, 0) AS so_dtl_shpws,Isnull(
       so_rtdtl_whstoretu, 0) AS so_rtdtl_whstoretu,Isnull(adage_sales_order_number, 0) AS adage_sales_order_number,
       Isnull(adage_sales_order_detail_sequence, 0) AS adage_sales_order_detail_sequence,[type],gl_cmp_key,gl_acct_key, 
       accounting_transaction_amount_type_name,accounting_transaction_detail_description,source_entry_datetime,
       accounting_transaction_dollar_amount,posted_flag,adage_update_user_id,adage_transaction_group_number,
       adage_subpost_number,so_rtdtl_crmoamt,rounded_allocated_adjustment,adage_document_type_code,adage_source_name,
       gl_row_count,rounded_gl_amount,adage_ordering_customer_id,adage_receiving_customer_id 
FROM  (SELECT a.system_of_record_natural_id,a.accounting_transaction_amount_type_name 
                     ,a.accounting_transaction_detail_description 
                     ,a.accounting_transaction_datetime,a.source_entry_datetime,a.accounting_transaction_dollar_amount
                     ,a.posted_flag,a.adage_update_user_id 
                     ,a.adage_transaction_group_number,a.adage_company_number,a.adage_subpost_number
                     ,a.adage_accounting_transaction_sequence,4 AS [type], 
              --non-revenue GL transactions related to the Credit Memo   
              NULL AS so_rtdtl_crmoamt,NULL AS rounded_allocated_adjustment,NULL AS so_resn_code,a.adage_source_code
                     ,a.adage_document_type_code,a.adage_source_name,a.adage_document_type_name,a.adage_branch_number
                     ,a.so_rtdtl_key,a.so_rthdr_key 
                     ,a.return_order_quantity,a.order_uom_code,a.return_stock_order_quantity,a.order_stock_uom_code
                     ,a.return_order_fill_quantity 
                     ,a.order_fill_uom_code,a.memo_stock_quantity,a.memo_stock_uom_code,a.memo_fill_quantity
                     ,a.memo_fill_uom_code,a.sales_type_code, 
                     a.adage_billing_customer_code,a.adage_product_key,a.adage_ordering_customer_id
                     ,a.adage_receiving_customer_id,a.so_dtl_shpws,a.so_rtdtl_whstoretu,a.adage_sales_order_number
                     ,a.adage_sales_order_detail_sequence 
                     ,a.gl_cmp_key,a.gl_acct_key,a.gl_row_count, 
              a.accounting_transaction_dollar_amount AS rounded_gl_amount 
       --INTO   #sales_return_order_accounting_transactions  
       --FROM   #sales_return_gl_source a  
       FROM   stg_sls_rtn_gl_src a 
       WHERE  a.[type] IS NULL 
       UNION ALL 
       --CN: Retunrs in 1:05 with 26533 compared to original of 0:44 26516 
       --Isolate AR-C transactions that reference RMA Detail breakout, but fail the GL transaction amount test (>.5% variance)
       --Query only returns a single row (without RMA Detail) for a given system_of_record_natural_id 
       SELECT a.system_of_record_natural_id,a.accounting_transaction_amount_type_name 
              ,a.accounting_transaction_detail_description 
              ,a.accounting_transaction_datetime,a.source_entry_datetime,a.accounting_transaction_dollar_amount
              ,a.posted_flag 
              ,a.adage_update_user_id 
              ,a.adage_transaction_group_number,a.adage_company_number,a.adage_subpost_number
              ,a.adage_accounting_transaction_sequence,5 AS [type], 
              --AR-C transactions that reference RMA Detail breakout, but fail the GL transaction amount test (>.5% variance)
              NULL AS so_rtdtl_crmoamt,NULL AS rounded_allocated_adjustment,NULL AS so_resn_code,a.adage_source_code
              ,a.adage_document_type_code,a.adage_source_name,a.adage_document_type_name,a.adage_branch_number
              ,a.so_rtdtl_key 
              ,a.so_rthdr_key 
              ,a.return_order_quantity,a.order_uom_code,a.return_stock_order_quantity,a.order_stock_uom_code
              ,a.return_order_fill_quantity 
              ,a.order_fill_uom_code,a.memo_stock_quantity,a.memo_stock_uom_code,a.memo_fill_quantity
              ,a.memo_fill_uom_code 
              ,a.sales_type_code 
              ,a.adage_billing_customer_code,a.adage_product_key,a.adage_ordering_customer_id
              ,a.adage_receiving_customer_id 
              ,a.so_dtl_shpws 
              ,a.so_rtdtl_whstoretu,a.adage_sales_order_number,a.adage_sales_order_detail_sequence,a.gl_cmp_key
              ,a.gl_acct_key 
              ,a.gl_row_count 
              ,a.accounting_transaction_dollar_amount AS rounded_gl_amount 
       --FROM   #sales_return_gl_source a  
       FROM   stg_sls_rtn_gl_src a 
              --INNER JOIN #remove_detail_gl_source b  
              INNER JOIN stg_rmv_dtl_gl_src b 
                      ON a.system_of_record_natural_id = b.system_of_record_natural_id 
                         AND a.gl_row_count = b.max_gl_row_count 
       --CN: Killed after 1 hour 
       --UNION ALL  
       ----Catchall for AR-C transactions that reference RMA Detail break and pass the GL transaction amount test (<=.5% variance)
       ----Apply rounding adjustment to the largest calculated credit amount   
       ----Checking for so_rtdtl_crmoamt IS NULL and setting to transaction amount was required for 1 row - a case where linking by Product from Credit Memo Detail to RMA Detail did not find the Credit Memo Product on an RMA Detail.
       --SELECT a.*  
       --       ,CASE  
       --          WHEN a.so_rtdtl_crmoamt IS NULL THEN a.accounting_transaction_dollar_amount  
       --          WHEN b.system_of_record_natural_id IS NULL THEN a.so_rtdtl_crmoamt  
       --                                                          + a.rounded_allocated_adjustment  
       --          ELSE a.so_rtdtl_crmoamt  
       --               + a.rounded_allocated_adjustment  
       --               + Round(Isnull(b.difference_transaction_dollar_amount, 0.0), 2)  
       --        END AS rounded_gl_amount  
       ----FROM   #sales_return_gl_source a  
       --FROM STG_SLS_RTN_GL_SRC a  
       --       LEFT OUTER JOIN (SELECT system_of_record_natural_id  
       --                               ,Round(Sum(so_rtdtl_crmoamt  
       --                                          + rounded_allocated_adjustment), 2)  
       --                                AS  
       --                                calculated_accounting_transaction_dollar_amount  
       --                               ,Round(Min(accounting_transaction_dollar_amount), 2) -  
       --                                Round(Sum(so_rtdtl_crmoamt  
       --                                          + rounded_allocated_adjustment), 2) AS  
       --                                difference_transaction_dollar_amount  
       --                               ,Max(gl_row_count)  
       --                                AS  
       --                                max_gl_row_count  
       --                        --FROM   #sales_return_gl_source  
       --            FROM STG_SLS_RTN_GL_SRC 
       --                        WHERE  [type] IS NOT NULL  
       --                        GROUP  BY system_of_record_natural_id  
       --                        HAVING Round(Min(accounting_transaction_dollar_amount), 2) <>  
       --                               Round(Sum(so_rtdtl_crmoamt  
       --                                         + rounded_allocated_adjustment), 2)) b  
       --                    ON a.system_of_record_natural_id = b.system_of_record_natural_id  
       --                       AND a.gl_row_count = b.max_gl_row_count  
       --WHERE  a.[type] IS NOT NULL  
       --   AND NOT EXISTS (SELECT 1  
       --                   --FROM   #remove_detail_gl_source c  
       --           FROM STG_RMV_DTL_GL_SRC c  
       --                   WHERE  a.system_of_record_natural_id = c.system_of_record_natural_id)  
       --CN: 2:19 81984 wo immediate above compared to 1:54 81967 
       UNION ALL 
       --AI: Insert IN-S Query HERE -- complete with RMA detail-level attributes pulled in   
       SELECT Cast(a.gl_subpost_key AS VARCHAR(10)) 
              + '-' 
              + Cast(a.gl_interface_seqno AS VARCHAR(10)) AS system_of_record_natural_id, 
              --Concatenated system of record natural ID   
              CASE 
                WHEN a.gl_interface_dbamt != 0.0 THEN 'debit' 
                ELSE 'credit' 
              END AS accounting_transaction_amount_type_name, 
              a.gl_interface_desc AS accounting_transaction_detail_description 
              ,a.gl_interface_date AS accounting_transaction_datetime,a.gl_interface_crtdt AS source_entry_datetime,CASE
                     WHEN a.gl_interface_dbamt != 0.0 THEN a.gl_interface_dbamt 
                     ELSE a.gl_interface_cramt 
                     END AS accounting_transaction_dollar_amount,CASE 
                                                                   WHEN gl_interface_postf = 1 THEN 'Y'
                                                                   ELSE 'N' 
                                                                 END AS posted_flag, 
              a.sa_user_key AS adage_update_user_id 
              ,a.gl_tran_key AS adage_transaction_group_number,a.gl_cmp_key AS adage_company_number,
              a.gl_subpost_key AS adage_subpost_number, 
              a.gl_interface_seqno AS adage_accounting_transaction_sequence,3 AS [type], 
              --AR-C transactions that reference RMA Detail break and pass the GL transaction amount test (<=.5% variance)
              b.so_rtdtl_crmoamt,NULL AS rounded_allocated_adjustment,b.so_resn_code, 
              a.gl_interface_srce AS adage_source_code 
              ,a.gl_interface_docty AS adage_document_type_code,e.gl_appcd_desc AS adage_source_name,
              f.gl_appdoc_desc AS adage_document_type_name 
              ,a.gl_intface_origent AS adage_branch_number,b.so_rtdtl_key,b.so_rthdr_key, 
              b.so_rtdtl_rmaqty AS return_order_quantity 
              ,b.so_rtdtl_rmauom AS order_uom_code,b.so_rtdtl_skuqty AS return_stock_order_quantity,CASE
                     WHEN b.so_rtdtl_skuuom = '' THEN g.in_prod_uom 
                     ELSE b.so_rtdtl_skuuom 
                     END AS order_stock_uom_code,b.so_rtdtl_rtfllqty AS return_order_fill_quantity,
              b.en_uom_filluom AS order_fill_uom_code,NULL AS memo_stock_quantity,NULL AS memo_stock_uom_code,NULL AS
              memo_fill_quantity,NULL AS memo_fill_uom_code,b.so_dtl_sltyp AS sales_type_code,
              k.en_cust_key AS adage_billing_customer_code,b.so_prod_key AS adage_product_key,
              h.en_cust_key AS adage_ordering_customer_id,i.en_cust_key AS adage_receiving_customer_id,g.so_dtl_shpws
              ,b.so_rtdtl_whstoretu,h.so_hdr_key AS adage_sales_order_number, 
              g. so_dtl_key AS adage_sales_order_detail_sequence 
              ,a.gl_cmp_key 
              ,a.gl_acct_key,NULL AS gl_row_count,NULL AS rounded_gl_amount 
       --FROM   gl_interface_tbl a  
       FROM   stg_gl_interface_tbl a 
              JOIN stg_so_rtdtl_tbl b 
                ON a.gl_cmp_orig = b.gl_cmp_key 
                   AND a.gl_intface_origent = b.so_brnch_key 
                   AND a.gl_intface_origdoc = b.so_rthdr_key 
                   AND a.gl_interface_ref3 = b.so_rtdtl_key 
              LEFT OUTER JOIN stg_gl_appcd_tbl e 
                           ON a.gl_interface_srce = e.gl_appcd_key 
              LEFT OUTER JOIN stg_gl_appdoc_tbl f 
                           ON a.gl_interface_srce = f.gl_appcd_key 
                              AND a.gl_interface_docty = f.gl_appdoc_key 
              LEFT OUTER JOIN stg_so_dtl_tbl g 
                           ON b.so_hdr_key = g.so_hdr_key 
                              AND b.so_dtl_key = g.so_dtl_key 
                              AND b.gl_cmp_key = g.gl_cmp_key 
                              AND b.so_brnch_key = g.so_brnch_key 
              LEFT OUTER JOIN stg_so_hdr_tbl h 
                           ON g.so_hdr_key = h.so_hdr_key 
                              AND g.gl_cmp_key = h.gl_cmp_key 
                              AND g.so_brnch_key = h.so_brnch_key 
              LEFT OUTER JOIN stg_en_ship_tbl i 
                           ON g.ar_ship_key = i.en_ship_key 
              LEFT OUTER JOIN stg_so_rthdr_tbl j --Sales Order Return (RMA) Header   
                           ON b.gl_cmp_key = j.gl_cmp_key 
                              AND b.so_brnch_key = j.so_brnch_key 
                              AND b.so_rthdr_key = j.so_rthdr_key 
              LEFT OUTER JOIN stg_en_bill_tbl k--Enterprise Bill To   
                           ON j.ar_bill_key = k.en_bill_key 
       WHERE  a.gl_interface_srce = 'IN' 
          AND a.gl_interface_docty = 'S')a 
WHERE  a.accounting_transaction_dollar_amount <> 0 
--) 
----Finally:   
--SELECT system_of_record_natural_id + '_'  
--       + Cast(Isnull(so_rtdtl_key, 0) AS VARCHAR(255)) AS system_of_record_natural_id  
--       --adding so_rtdtl_key to natural key and setting as zero if null (those coming from memo side of the query)
--       ,adage_company_number  
--       ,accounting_transaction_datetime --Added in v8   
--       ,Isnull(so_resn_code, 'Unspecific')             AS so_resn_code  
--       ,adage_source_code  
--       ,adage_document_type_code  
--       ,adage_source_name  
--       ,adage_document_type_name  
--       ,adage_branch_number  
--       ,adage_accounting_transaction_sequence  
--       ,Isnull(so_rtdtl_key, 0)                        AS so_rtdtl_key  
--       ,Isnull(so_rthdr_key, 0)                        AS so_rthdr_key  
--       ,Isnull(return_order_quantity, 0)               AS return_order_quantity  
--       ,Isnull(order_uom_code, '0')                    AS order_uom_code  
--       ,Isnull(return_stock_order_quantity, 0)         AS return_stock_order_quantity  
--       ,Isnull(order_stock_uom_code, '0')              AS order_stock_uom_code  
--       ,Isnull(return_order_fill_quantity, 0)          AS return_order_fill_quantity  
--       ,Isnull(order_fill_uom_code, '0')               AS order_fill_uom_code  
--       ,Isnull(memo_stock_quantity, 0)                 AS memo_stock_quantity  
--       ,Isnull(memo_stock_uom_code, '0')               AS memo_stock_uom_code  
--       ,Isnull(memo_fill_quantity, 0)                  AS memo_fill_quantity  
--       ,Isnull(memo_fill_uom_code, '0')                AS memo_fill_uom_code  
--       ,Isnull(sales_type_code, 'Unspecific')          AS sales_type_code  
--       ,Isnull(adage_billing_customer_code, 0)         AS adage_billing_customer_code  
--       ,Isnull(adage_product_key, 0)                   AS adage_product_key  
--       ,Isnull(so_dtl_shpws, 0)                        AS so_dtl_shpws  
--       ,Isnull(so_rtdtl_whstoretu, 0)                  AS so_rtdtl_whstoretu  
--       ,Isnull(adage_sales_order_number, 0)            AS adage_sales_order_number  
--       ,Isnull(adage_sales_order_detail_sequence, 0)   AS adage_sales_order_detail_sequence 
--       ,[type]  
--       --below attributes new with v11 merge   
--       ,gl_cmp_key  
--       ,gl_acct_key  
--       ,accounting_transaction_amount_type_name  
--       ,accounting_transaction_detail_description  
--       ,source_entry_datetime  
--       ,accounting_transaction_dollar_amount  
--       ,posted_flag  
--       ,adage_update_user_id  
--       ,adage_transaction_group_number  
--       ,adage_subpost_number  
--FROM   STG_SLS_RTN_ORD_ACCT_TRNS  
----new line for v13 below:   
--WHERE  accounting_transaction_dollar_amount <> 0  
----100046   
----GO   