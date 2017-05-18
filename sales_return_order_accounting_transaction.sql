WITH stg_ar_dbcrmhdr_tbl 
     AS (--get debit/credit memo header info -- 
        SELECT gl_cmp_key 
               ,in_brnch_key 
               ,ar_dbcrm_type 
               ,ar_dbcrm_key 
               ,tran_date_key 
               ,comp_date_key 
               ,ar_bill_key 
               ,ar_dbcrm_amt 
               ,ar_ship_key 
         FROM   erp_int_sub.dbo.ar_dbcrmhdr_tbl), 
     stg_ar_dbcrm_tbl -- 
     AS (--get debit/credit memo DETEAIL info 
        SELECT MEMO_DTL.gl_cmp_key 
               ,MEMO_DTL.in_brnch_key 
               ,MEMO_DTL.ar_dbcrm_type 
               ,MEMO_DTL.ar_dbcrm_key 
               ,ar_dbcrdtl_key 
               ,so_prod_key 
               ,so_dtl_key 
               ,ar_dbcrm_afill 
               ,en_uom_afill 
               ,ar_dbcrm_skuqty 
               ,ar_dbcrm_skuuom 
               ,so_ship_date 
               ,MEMO_DTL.ar_ship_key 
         FROM   erp_int_sub.dbo.ar_dbcrm_tbl MEMO_DTL 
                INNER JOIN stg_ar_dbcrmhdr_tbl MEMO_HDR 
                        ON MEMO_HDR.gl_cmp_key = MEMO_DTL.gl_cmp_key 
                           AND MEMO_HDR.in_brnch_key = MEMO_DTL.in_brnch_key 
                           AND MEMO_HDR.ar_dbcrm_type = MEMO_DTL.ar_dbcrm_type 
                           AND MEMO_HDR.ar_dbcrm_key = MEMO_DTL.ar_dbcrm_key 
                           AND MEMO_HDR.ar_dbcrm_type = MEMO_DTL.ar_dbcrm_type), 
     stg_ar_dcmadj_tbl -- 
     AS (--get debit/credit adjusted memo info 
        SELECT DISTINCT gl_cmp_key 
                        ,so_brnch_key 
                        ,ar_dbcrm_type 
                        ,ar_dbcrm_key 
                        ,ar_dbcrdtl_key 
                        ,ar_dcmadj_keytyp 
                        ,Isnull(ar_dcmadj_examtc, 0.0) * -1 AS ar_dcmadj_examtc 
         FROM   erp_int_sub.dbo.ar_dcmadj_tbl 
         WHERE  ar_dcmadj_keytyp = 1 --ar_dcmadj_keytyp: Adjustment/Promotion (0 = price adjustment, 1 = N/A) 
        ), 
     stg_so_rtdtl_tbl -- 
     AS (--get sales return detail info 
        SELECT SRO.gl_cmp_key 
               ,so_brnch_key 
               ,so_rthdr_key 
               ,so_rtdtl_key 
               ,so_prod_key 
               ,SRO.ar_dbcrm_type 
               ,so_rtdtl_rmaqty --AS return_order_quantity 
               ,so_rtdtl_rmauom --AS order_uom_code 
               ,so_resn_code 
               ,so_hdr_key 
               ,SRO.so_dtl_key 
               ,so_rtdtl_skuqty --AS return_stock_order_quantity 
               ,so_rtdtl_skuuom --AS order_stock_uom_code --use so_dtl_tbl.in_prd_uom for nulls 
               ,so_rtdtl_whstoretu 
               ,in_lot_key 
               ,so_dtl_sltyp-- AS sales_type_code 
               ,SRO.ar_dbcrm_key 
               ,Round(so_rtdtl_crmoamt, 2) AS so_rtdtl_crmoamt 
               ,so_rtdtl_rtfllqty-- AS return_order_fill_quantity 
               ,SRO.ar_dbcrdtl_key 
               ,en_uom_filluom 
         FROM   erp_int_sub.dbo.so_rtdtl_tbl SRO), 
     stg_so_rthdr_tbl --CN Can Remove 
     AS (--get sales return header info 
        SELECT DISTINCT SRH.gl_cmp_key 
                        ,SRH.so_brnch_key 
                        ,SRH.so_rthdr_key 
                        ,so_rthdr_rtdt 
                        ,en_cust_key 
                        ,ar_bill_key --,SRH.so_resn_code 
                        ,SRH.so_hdr_key 
                        ,ar_ship_key 
                        ,gl_crncy_key --not in original mapping, but may be useful 
         FROM   erp_int_sub.dbo.so_rthdr_tbl SRH 
                INNER JOIN stg_so_rtdtl_tbl SRD 
                        ON SRD.gl_cmp_key = SRH.gl_cmp_key 
                           AND SRD.so_brnch_key = SRH.so_brnch_key 
                           AND SRD.so_rthdr_key = SRH.so_rthdr_key --where so_rthdr_rtdt > '12/31/2014 11:59:59 PM' 
        ), 
     stg_so_brprd_tbl --CN Can Remove 
     AS (--get branch product info 
        SELECT DISTINCT SBP.gl_cmp_key 
                        ,so_brnch_key 
                        ,SBP.so_prod_key 
                        ,so_brprd_sales --used to drive gl_acct_key 
                        ,so_brprd_serv 
         FROM   erp_int_sub.dbo.so_brprd_tbl SBP 
                INNER JOIN stg_ar_dbcrm_tbl DCH 
                        ON DCH.gl_cmp_key = SBP.gl_cmp_key 
                           AND DCH.in_brnch_key = SBP.so_brnch_key 
                           AND DCH.so_prod_key = SBP.so_prod_key), 
     stg_so_prod_tbl 
     AS (--get product info --CN Can Remove 
        SELECT DISTINCT PRD.gl_cmp_key 
                        ,PRD.so_prod_key 
                        ,so_prod_desc --,in_item_key --could have value 
                        ,so_prod_shipf 
         FROM   erp_int_sub.dbo.so_prod_tbl PRD 
                INNER JOIN stg_ar_dbcrm_tbl DCH 
                        ON DCH.gl_cmp_key = PRD.gl_cmp_key 
                           AND DCH.so_prod_key = PRD.so_prod_key), 
     stg_en_sltyp_glid 
     AS (--get sales type info --CN Can Remove 
        SELECT en_sltyp_key 
               ,en_sltyp_desc 
               ,Isnull(en_sltyp_glid, '00') AS en_sltyp_glid 
         FROM   erp_int_sub.dbo.en_sltyp_tbl), 
     stg_en_bill_tbl -- 
     AS (SELECT --get enterprose bill to 
        en_bill_key 
        ,en_cust_key 
         FROM   erp_int_sub.dbo.en_bill_tbl), 
     stg_ar_dbcrm_tbl_agg 
     AS (SELECT MDTL.gl_cmp_key 
                ,MDTL.in_brnch_key 
                ,MDTL.ar_dbcrm_type 
                ,MDTL.ar_dbcrm_key 
                ,MADJ.ar_dcmadj_keytyp --1 
                ,Sum(Isnull(MADJ.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc 
                ,Sum(MDTL.ar_dbcrm_skuqty)                    AS total_memo_stock_quantity 
                ,Sum(MDTL.ar_dbcrm_afill)                     AS total_memo_fill_quantity 
                ,Max(MDTL.en_uom_afill)                       AS memo_fill_uom_code 
                ,Max(MDTL.ar_dbcrm_skuuom)                    AS memo_stock_uom_code 
         FROM   stg_ar_dbcrm_tbl MDTL 
                LEFT OUTER JOIN stg_ar_dcmadj_tbl MADJ 
                             ON MDTL.gl_cmp_key = MADJ.gl_cmp_key 
                                AND MDTL.in_brnch_key = MADJ.so_brnch_key 
                                AND MDTL.ar_dbcrm_type = MADJ.ar_dbcrm_type 
                                AND MDTL.ar_dbcrm_key = MADJ.ar_dbcrm_key 
                                AND MDTL.ar_dbcrdtl_key = MADJ.ar_dbcrdtl_key 
         WHERE  MADJ.ar_dcmadj_keytyp = 1 --ar_dcmadj_keytyp: Adjustment/Promotion (0 = price adjustment, 1 = N/A) 
         GROUP  BY MDTL.gl_cmp_key 
                   ,MDTL.in_brnch_key 
                   ,MDTL.ar_dbcrm_type --C 
                   ,MDTL.ar_dbcrm_key 
                   ,MADJ.ar_dcmadj_keytyp), 
     stg_en_prod_tbl 
     AS (--get product description--CN Not Used 
        SELECT --distinct 
        en_prod_key 
        ,en_prod_desc 
        ,Cast(en_item_key + CASE WHEN im_pack_key <> '' THEN '-' + im_pack_key ELSE '' END AS VARCHAR(40)) AS 
         material_id 
         FROM   erp_int_sub.dbo.en_prod_tbl prd --inner join STG_SO_DTL_TBL sod on 
        ), 
     stg_so_dtl_tbl 
     AS (SELECT so_hdr_key 
                ,so_dtl_key 
                ,gl_cmp_key 
                ,so_brnch_key 
                ,in_prod_uom 
         FROM   erp_int_sub.dbo.so_dtl_tbl i), 
     stg_ar_dbcrm_adj_agg 
     AS (SELECT aa.gl_cmp_key 
                ,aa.in_brnch_key 
                ,aa.ar_dbcrm_key 
                ,aa.so_prod_key 
                ,Sum(Isnull(bb.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc 
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
         GROUP  BY aa.gl_cmp_key 
                   ,aa.in_brnch_key 
                   ,aa.ar_dbcrm_key 
                   ,aa.so_prod_key) 
,STG_GL_INTERFACE_TBL AS(--get general ledger interface info--
  SELECT
    gli.gl_subpost_key
    ,gli.gl_interface_seqno
    ,gli.gl_cmp_key
    ,gli.gl_interface_date
    ,gli.gl_interface_srce 
    ,gli.gl_interface_docty
    ,gli.gl_interface_entid
    ,gl_interface_ref2
    ,gli.gl_acct_key
    ,gl_interface_crtdt
    ,gli.gl_interface_cramt
    ,gli.gl_interface_dbamt
    ,gli.gl_interface_docno
    ,gli.sa_user_key
    ,gli.gl_tran_key
    ,gli.gl_interface_desc
    ,gli.gl_interface_postf
    ,gli.gl_perod_seqno
    ,so_prod_key
FROM
  ERP_Int_Sub.dbo.gl_interface_tbl gli
WHERE 
  gli.gl_interface_srce = 'AR' and
  gl_interface_docty in ('c','d') --for memo
)
/*,STG_ADJ_ALLOCATION AS( 
  SELECT  
    a.*,  
    --Case statement below remedies divide by zero risk 
    ROUND(a.ar_dcmadj_examtc * CASE WHEN a.so_rtdtl_crmoamt = 0.0 THEN 1.0 ELSE a.so_rtdtl_crmoamt END / CASE WHEN b.total_credit = 0.0 THEN 1.0 ELSE ISNULL(b.total_credit, 1.0) END, 2) AS allocated_adjustment, 
    b.total_credit,  
    b.max_row_count  
  --INTO #adjustment_allocation  
  FROM #sales_return_detail_source a  
  LEFT OUTER JOIN --Roll up of the detail level data to a header-level total credit amount 
    ( 
    SELECT aa.gl_cmp_key, aa.in_brnch_key, aa.ar_dbcrm_type, aa.ar_dbcrm_key, aa.ar_dbcrdtl_key, aa.adage_product_key, aa.ar_dcmadj_examtc, MAX(aa.row_count) AS max_row_count, SUM(aa.so_rtdtl_crmoamt) AS total_credit 
    FROM #sales_return_detail_source aa  
    GROUP BY aa.gl_cmp_key, aa.in_brnch_key, aa.ar_dbcrm_type, aa.ar_dbcrm_key, aa.ar_dbcrdtl_key, aa.adage_product_key, aa.ar_dcmadj_examtc
    ) b ON a.gl_cmp_key = b.gl_cmp_key AND a.in_brnch_key = b.in_brnch_key AND a.ar_dbcrm_type = b.ar_dbcrm_type AND a.ar_dbcrm_key = b.ar_dbcrm_key AND ISNULL(a.ar_dbcrdtl_key, '') = ISNULL(b.ar_dbcrdtl_key, '') AND a.adage_product_key = b.adage_product_key
)*//* 
   ,STG_RND_ADJ_ALLOCATION AS( 
   SELECT  
       a.*,  
       CASE WHEN ROUND(a.ar_dcmadj_examtc, 2) <> ROUND(b.total_allocated_adjustment, 2) AND a.row_count = a.max_row_count THEN a.allocated_adjustment + ROUND(a.ar_dcmadj_examtc, 2) - ROUND(b.total_allocated_adjustment, 2) ELSE a.allocated_adjustment END AS rounded_allocated_adjustment 
     --INTO #rounded_adjustment_allocation  
     FROM #adjustment_allocation a  
     LEFT OUTER JOIN  --Roll up of the detail level data to a header-level total allocated adjustment amount 
       ( 
       SELECT aa.gl_cmp_key, aa.in_brnch_key, aa.ar_dbcrm_type, aa.ar_dbcrm_key, aa.ar_dbcrdtl_key, aa.adage_product_key, ROUND(SUM(aa.allocated_adjustment), 2) AS total_allocated_adjustment 
       FROM #adjustment_allocation aa  
       GROUP BY aa.gl_cmp_key, aa.in_brnch_key, aa.ar_dbcrm_type, aa.ar_dbcrm_key, aa.ar_dbcrdtl_key, aa.adage_product_key
       ) b ON a.gl_cmp_key = b.gl_cmp_key AND a.in_brnch_key = b.in_brnch_key AND a.ar_dbcrm_type = b.ar_dbcrm_type AND a.ar_dbcrm_key = b.ar_dbcrm_key AND ISNULL(a.ar_dbcrdtl_key, '') = ISNULL(b.ar_dbcrdtl_key, '') AND a.adage_product_key = b.adage_product_key
    
   )*/ 
/****************************************************************************************** 
******************************************************************************************/ 
--Relate Credit Memo Details to RMA Details 
--Note: ROW_NUMBER added to prepare for Credit Memo Adjustment allocation and to correct rounding on the largest credit amount.
--Top half of query below: 
--Credit Memo without RMA detail tie. 
--More specifically, relate Credit Memo Details to RMA Details for RMA Details that have a missing Credit Memo Detail ID - thus related by Product instead.
--select count(*) 
--from STG_AR_DBCRMHDR_TBL a 
----INNER JOIN STG_AR_DBCRM_TBL--Debit/Credit Memo Header 
----        ON STG_AR_DBCRMHDR_TBL.gl_cmp_key = STG_AR_DBCRM_TBL.gl_cmp_key 
----        AND STG_AR_DBCRMHDR_TBL.in_brnch_key = STG_AR_DBCRM_TBL.in_brnch_key 
----        AND STG_AR_DBCRMHDR_TBL.ar_dbcrm_key = STG_AR_DBCRM_TBL.ar_dbcrm_key 
----        AND (STG_AR_DBCRM_TBL.ar_dbcrm_type = 'C' --Credit 
----        ) 
--INNER JOIN STG_AR_DBCRM_ADJ_AGG b 
--ON a.gl_cmp_key = b.gl_cmp_key AND a.in_brnch_key = b.in_brnch_key AND a.ar_dbcrm_type = 'C' AND a.ar_dbcrm_key = b.ar_dbcrm_key
--LEFT OUTER JOIN STG_SO_RTDTL_TBL c --Sales Order Return (RMA) Detail 
-- ON c.ar_dbcrdtl_key IS NULL AND b.gl_cmp_key = c.gl_cmp_key AND b.in_brnch_key = c.so_brnch_key AND b.ar_dbcrm_key = c.ar_dbcrm_key AND b.so_prod_key = c.so_prod_key
--LEFT OUTER JOIN STG_SO_RTHDR_TBL d --Sales Order Return (RMA) Header 
-- ON c.gl_cmp_key = d.gl_cmp_key AND c.so_brnch_key = d.so_brnch_key AND c.so_rthdr_key = d.so_rthdr_key
--INNER JOIN STG_SO_BRPRD_TBL e --Branch-Product 
-- ON b.gl_cmp_key = e.gl_cmp_key AND b.in_brnch_key = e.so_brnch_key AND b.so_prod_key = e.so_prod_key
--INNER JOIN STG_SO_PROD_TBL f --Product 
-- ON b.gl_cmp_key = f.gl_cmp_key AND b.so_prod_key = f.so_prod_key 
----INNER JOIN STG_SO_RTDTL_TBL rt 
----  ON b.gl_cmp_key = rt.gl_cmp_key AND b.in_brnch_key = rt.so_brnch_key AND b.ar_dbcrm_key = rt.ar_dbcrm_key
----  AND rt.ar_dbcrdtl_key IS NULL 
--LEFT OUTER JOIN STG_EN_SLTYP_GLID g --Sales Type Detail 
-- ON c.so_dtl_sltyp = g.en_sltyp_key 
--left outer join STG_EN_BILL_TBL h--Enterprise Bill To 
-- on d.ar_bill_key = h.en_bill_key 
--left outer join STG_SO_DTL_TBL i 
-- on c.so_hdr_key = i.so_hdr_key 
-- and c.so_dtl_key = i.so_dtl_key 
-- and c.gl_cmp_key = i.gl_cmp_key 
-- and c.so_brnch_key = i.so_brnch_key 
----where there is no tie to RMA detail 
--WHERE EXISTS 
-- ( 
-- SELECT 1 
-- FROM STG_SO_RTDTL_TBL h 
-- WHERE h.ar_dbcrdtl_key IS NULL AND b.gl_cmp_key = h.gl_cmp_key AND b.in_brnch_key = h.so_brnch_key AND b.ar_dbcrm_key = h.ar_dbcrm_key
-- ) 
---- 
-- 
SELECT a.gl_cmp_key 
       ,a.in_brnch_key 
       ,a.ar_dbcrm_type 
       ,a.ar_dbcrm_key 
       ,c.ar_dbcrdtl_key 
       ,--Deriving the gl_account_key 
       CASE 
          WHEN f.so_prod_shipf = 1 --shippable product flag 
        THEN Replace(e.so_brprd_sales, '@@', Isnull(g.en_sltyp_glid, '00')) 
          --if it is a shippable product then use the Branch Product Sales Account 
          ELSE Replace(e.so_brprd_serv, '@@', Isnull(g.en_sltyp_glid, '00')) 
        --if it is not a shippable product then use the Branch Product Service Account 
        END                              AS gl_acct_key 
       ,c.so_rtdtl_key 
       ,c.so_rthdr_key 
       ,c.so_hdr_key 
       ,c.so_dtl_key 
       ,b.so_prod_key                    AS adage_product_key 
       ,c.in_lot_key 
       ,c.so_dtl_sltyp 
       ,c.so_resn_code 
       ,c.so_rtdtl_rmaqty 
       ,Round(c.so_rtdtl_crmoamt, 2)     AS so_rtdtl_crmoamt 
       ,NULL                             AS ar_dcmadj_examtc 
       ,--b.ar_dcmadj_examtc, --CN FIX 
       d.en_cust_key 
       ,c.so_rtdtl_rmaqty                AS return_order_quantity 
       ,c.so_rtdtl_rmauom                AS order_uom_code 
       ,c.so_rtdtl_skuqty                AS return_stock_order_quantity 
       ,--c.so_rtdtl_skuuom as order_stock_uom_code, 
       CASE 
          WHEN c.so_rtdtl_skuuom = '' THEN i.in_prod_uom 
          ELSE c.so_rtdtl_skuuom 
        END                              AS order_stock_uom_code 
       ,c.so_rtdtl_rtfllqty              AS return_order_fill_quantity 
       ,c.en_uom_filluom                 AS order_fill_uom_code 
       ,NULL                             AS memo_stock_quantity 
       ,NULL                             AS memo_stock_uom_code 
       ,NULL                             AS memo_fill_quantity 
       ,NULL                             AS memo_fill_uom_code 
       ,c.so_dtl_sltyp                   AS sales_type_code 
       ,h.en_cust_key                    AS adage_billing_customer_code 
       ,c.so_rtdtl_whstoretu 
       , 
       --Numbering by return detail credit amount for subsequent adjustment allocation to the detail line with greatest amount:
       Row_number() 
          OVER( 
            partition BY a.gl_cmp_key, a.in_brnch_key, a.ar_dbcrm_type, a.ar_dbcrm_key, b.so_prod_key
            ORDER BY c.so_rtdtl_crmoamt) AS row_count 
,Cast(k.gl_subpost_key AS VARCHAR(10)) 
       + '-' 
       + Cast(k.gl_interface_seqno AS VARCHAR(10))                        AS system_of_record_natural_id

--SELECT distinct b.[gl_cmp_key]+'-'+b.[in_brnch_key]+'-'+b.[ar_dbcrm_type]+'-'+b.[ar_dbcrm_key] AS key1 
FROM   stg_ar_dbcrmhdr_tbl a 
       INNER JOIN stg_ar_dbcrm_tbl b --Debit/Credit Memo Header 
               ON a.gl_cmp_key = b.gl_cmp_key 
                  AND a.in_brnch_key = b.in_brnch_key 
                  AND a.ar_dbcrm_key = b.ar_dbcrm_key 
                  AND ( b.ar_dbcrm_type = 'C' --Credit 
                         OR a.ar_dbcrm_type = b.ar_dbcrm_type ) --From Union All 
       INNER JOIN stg_so_brprd_tbl e --Branch-Product--CN Removed 4/12 - not restrictive 
               ON b.gl_cmp_key = e.gl_cmp_key 
                  AND b.in_brnch_key = e.so_brnch_key 
                  AND b.so_prod_key = e.so_prod_key 
       INNER JOIN stg_so_prod_tbl f --Product--CN Removed 4/12 - not restrictive 
               ON b.gl_cmp_key = f.gl_cmp_key 
                  AND b.so_prod_key = f.so_prod_key 
       INNER JOIN stg_so_rtdtl_tbl c --Sales Order Return (RMA) Detail --CN 5/18 Changed to Left outer--Removed to large return
               ON c.gl_cmp_key = b.gl_cmp_key 
                  AND c.so_brnch_key = b.in_brnch_key 
                  AND c.ar_dbcrm_key = b.ar_dbcrm_key 
                  AND ( c.ar_dbcrdtl_key IS NULL 
                         OR c.ar_dbcrdtl_key = b.ar_dbcrdtl_key )
       --      LEFT OUTER JOIN so_rtdtl_tbl c --Sales Order Return (RMA) Detail 
       --        --ON c.ar_dbcrdtl_key IS NULL 
       --        ON b.gl_cmp_key = c.gl_cmp_key 
       --        AND b.in_brnch_key = c.so_brnch_key 
       --        AND b.ar_dbcrm_key = c.ar_dbcrm_key 
       --        AND b.so_prod_key = c.so_prod_key 
       --        AND (c.ar_dbcrm_type = 'C' --Credit 
       --          OR c.ar_dbcrm_type IS NULL) 
       LEFT OUTER JOIN stg_so_rthdr_tbl d --Sales Order Return (RMA) Header 
                    ON c.gl_cmp_key = d.gl_cmp_key 
                       AND c.so_brnch_key = d.so_brnch_key 
                       AND c.so_rthdr_key = d.so_rthdr_key 
       LEFT OUTER JOIN stg_en_sltyp_glid g --Sales Type Detail 
                    ON c.so_dtl_sltyp = g.en_sltyp_key 
       LEFT OUTER JOIN stg_en_bill_tbl h --Enterprise Bill To 
                    ON d.ar_bill_key = h.en_bill_key 
       LEFT OUTER JOIN stg_so_dtl_tbl i 
                    ON c.so_hdr_key = i.so_hdr_key 
                       AND c.so_dtl_key = i.so_dtl_key 
                       AND c.gl_cmp_key = i.gl_cmp_key 
                       AND c.so_brnch_key = i.so_brnch_key 
       LEFT OUTER JOIN 
       --Adjustment amount for credits and applicable adjustment type only. Aggregated up from the detail level.
       (SELECT aa.gl_cmp_key --CN TURN INTO AGG TABLE
               ,aa.so_brnch_key 
               ,aa.ar_dbcrm_type 
               ,aa.ar_dbcrm_key 
               ,aa.ar_dbcrdtl_key 
               ,Sum(Isnull(aa.ar_dcmadj_examtc, 0.0) * -1) AS ar_dcmadj_examtc 
        FROM 
       --ar_dcmadj_tbl aa 
       stg_ar_dcmadj_tbl aa 
        WHERE  aa.ar_dbcrm_type = 'C' --Credits only 
           AND aa.ar_dcmadj_keytyp = 1 --Applicable adjustment type only 
        GROUP  BY aa.gl_cmp_key 
                  ,aa.so_brnch_key 
                  ,aa.ar_dbcrm_type 
                  ,aa.ar_dbcrm_key 
                  ,aa.ar_dbcrdtl_key) j 
                    ON b.gl_cmp_key = j.gl_cmp_key 
                       AND b.in_brnch_key = j.so_brnch_key 
                       AND b.ar_dbcrm_type = j.ar_dbcrm_type 
                       AND b.ar_dbcrm_key = j.ar_dbcrm_key 
                       AND b.ar_dbcrdtl_key = j.ar_dbcrdtl_key 
--CN Added 5/18
LEFT OUTER JOIN STG_GL_INTERFACE_TBL k
                    ON k.gl_cmp_key = a.gl_cmp_key 
                       AND k.gl_interface_entid = a.in_brnch_key 
                       AND k.gl_interface_docty = a.ar_dbcrm_type 
                       AND k.gl_interface_docno = a.ar_dbcrm_key 
                       AND k.gl_acct_key =  
							CASE		
							WHEN f.so_prod_shipf = 1 --shippable product flag 
							THEN Replace(e.so_brprd_sales, '@@', Isnull(g.en_sltyp_glid, '00')) 
							--if it is a shippable product then use the Branch Product Sales Account 
							ELSE Replace(e.so_brprd_serv, '@@', Isnull(g.en_sltyp_glid, '00')) 
							--if it is not a shippable product then use the Branch Product Service Account 
							END
WHERE  a.ar_dbcrm_type = 'C' 
--    GROUP BY 
--      b.gl_cmp_key 
--      ,b.in_brnch_key 
--      ,b.ar_dbcrm_key 
--      ,b.so_prod_key 
--      ,b.ar_dbcrm_type 