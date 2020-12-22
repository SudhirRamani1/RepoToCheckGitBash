CREATE OR REPLACE PACKAGE BODY ESM_OWNER.Esm_Utl_Lilly
AS
    FUNCTION GET_DOCUMENT_LIST (pi_case_id INTEGER)
        --*******************************************************************************************************************************
        --** Created by: Pradip Shah                                                                                                   **
        --** Creation Date: 07/10/2001                                                                                                 **
        --** Purpose: Returns Document list coma separated                                                                             **
        --**                                                                                                                           **
        --** Inputs: pi_case_id -   case_notes_attach.case_id                                                                          **
        --**                                                                                                                           **
        --** Outputs: Document list                                                                                                    **
        --**                                                                                                                           **
        --** Definitions: pi - parameter in                                                                                            **
        --**              po - parameter out                                                                                           **
        --**               v - varchar2 variable                                                                                       **
        --**               n - numeric variable                                                                                        **
        --**               i - integer variable                                                                                        **
        --**              cl - clob variable                                                                                           **
        --**               e - exception                                                                                               **
        --**               c - cursor                                                                                                  **
        --**               d - date                                                                                                    **
        --**              cp - cursor parameter                                                                                        **
        --**                                                                                                                           **
        --** Modification History:                                                                                                     **
        --** Name: Phanindra Garapati, C236122                                                                                         **
        --** Date: 15-mar-2019                                                                                                         **
        --** Purpose: To fix the issue for change #CHG1400611                                                                          **
        --**          DOCUMENTLIST error -ORA-06502: PL/SQL: Numeric or value error: character string buffer too small                 **
        --*******************************************************************************************************************************
        RETURN VARCHAR2
    IS
        notes   VARCHAR2 (32676) := NULL;

        CURSOR c1
        IS
            SELECT case_notes_attach.notes notes
              FROM case_notes_attach, lm_classification
             WHERE     case_id = pi_case_id
                   AND case_notes_attach.classification = classification_id
                   AND e2b_additional_doc = 1;
    BEGIN
        FOR z IN c1
        LOOP
            IF notes IS NULL
            THEN
                notes := z.notes;
            ELSE
                IF LENGTH (notes) > 1000
                THEN
                    notes := SUBSTR (notes, 1, 1000);
                END IF;

                notes := notes || ',' || z.notes;
            END IF;
        END LOOP;

        RETURN notes;
    END GET_DOCUMENT_LIST;

    FUNCTION f_qualification (pi_hcp_flag           NUMBER,
                              pi_reporter_type      VARCHAR2,
                              pi_intermediary_id    NUMBER)
        --**************************************************************************************************************************
        --** Modification History:                                                                                                     **
        --** Atin Goyal   01-Nov-2012  CR06231863                                                                                 **
        --** Purpose:  Change the export map for Qualification as per changed value of reporter type                          **
        --**************************************************************************************************************************
        RETURN NUMBER
    IS
    BEGIN
        IF     pi_hcp_flag = 1
           AND pi_reporter_type IN ('Physician', 'Study Investigator')
        THEN
            RETURN 1;
        ELSIF pi_hcp_flag = 1 AND pi_reporter_type = 'Pharmacist'
        THEN
            RETURN 2;
        ELSIF pi_hcp_flag = 1 AND pi_reporter_type IN ('Nurse', 'Other HCP')
        THEN
            RETURN 3;
        ELSIF pi_reporter_type = 'Lawyer'
        THEN
            RETURN 4;
        ELSE
            RETURN 5;
        END IF;
    END f_qualification;

    FUNCTION GET_OBSERVESTUDYTYPE (pi_case_id INTEGER)
        --*******************************************************************************************************************************
        --** Created by: Pradip Shah                                                                                                   **
        --** Creation Date: 12/7/2006                                                                                                  **
        --** Purpose: Returns lm_case_classification.E2B_CODE to populate primarysource.OBSERVESTUDYTYPE                               **
        --**                                                                                                                           **
        --** Inputs: pi_case_id - case_reporters.case_id                                                                               **
        --**                                                                                                                           **
        --** Outputs: primarysource.OBSERVESTUDYTYPE                                                                                   **
        --**                                                                                                                           **
        --** Definitions: pi - parameter in                                                                                            **
        --**              po - parameter out                                                                                           **
        --**               v - varchar2 variable                                                                                       **
        --**               n - numeric variable                                                                                        **
        --**               i - integer variable                                                                                        **
        --**              cl - clob variable                                                                                           **
        --**               e - exception                                                                                               **
        --**               c - cursor                                                                                                  **
        --**               d - date                                                                                                    **
        --**              cp - cursor parameter                                                                                        **
        --**                                                                                                                           **
        --** Modification History:                                                                                                     **
        --** Date:                                                                                                                     **
        --** Purpose:                                                                                                                  **
        --*******************************************************************************************************************************
        RETURN INTEGER
    IS
        l_e2b         NUMBER;
        v_study_key   case_study.study_key%TYPE;
    BEGIN
        SELECT study_key
          INTO v_study_key
          FROM case_study
         WHERE case_id = pi_case_id;

        SELECT lcc.E2B_CODE
          INTO l_e2b
          FROM lm_case_classification lcc, lm_studies ls
         WHERE     ls.classification_id = lcc.classification_id
               AND ls.study_key = v_study_key;

        RETURN l_e2b;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END GET_OBSERVESTUDYTYPE;

    --*******************************************************************************
    --** f_us_territory
    --**
    --** Barb Chappell    CR05632800    Use country grouping instead of hardcoded list of A2 values
    --****************************************************************
    FUNCTION f_us_territory (pi_a2_country VARCHAR2)
        RETURN NUMBER
    IS
        v_country_group   lm_countries.country_group%TYPE;
    BEGIN
        SELECT country_group
          INTO v_country_group
          FROM lm_countries
         WHERE a2 = pi_a2_country;

        IF pi_a2_country = 'US' OR v_country_group = 'UNITED STATES'
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END f_us_territory;

    FUNCTION GET_STUDYNAME (pi_case_id      INTEGER,
                            pi_seq_num      INTEGER,
                            pi_rownum       INTEGER,
                            pi_agency_id    INTEGER)
        --*******************************************************************************************************************************
        --** Created by: Scott J. Clark                                                                                                **
        --** Creation Date: 02/6/2001                                                                                                  **
        --** Purpose: Returns lm_studies.study_desc which is used to populate primarysource.studyname                                  **
        --**                                                                                                                           **
        --** Inputs: pi_case_id - case_reporters.case_id                                                                               **
        --**         pi_seq_num - case_reporters.seq_num                                                                               **
        --**         pi_rownum - rownum                                                                                                **
        --**                                                                                                                           **
        --** Outputs: primarysource.studyname                                                                                          **
        --**                                                                                                                           **
        --** Definitions: pi - parameter in                                                                                            **
        --**              po - parameter out                                                                                           **
        --**               v - varchar2 variable                                                                                       **
        --**               n - numeric variable                                                                                        **
        --**               i - integer variable                                                                                        **
        --**              cl - clob variable                                                                                           **
        --**               e - exception                                                                                               **
        --**               c - cursor                                                                                                  **
        --**               d - date                                                                                                    **
        --**              cp - cursor parameter                                                                                        **
        --**                                                                                                                           **
        --** Modification History:                                                                                                     **
        --**  Barb Chappell   23-Apr-2009  CR05632800   Pull studyname from lm_studies and not from case_study  \--**  Atin Goyal      20-Nov-2013  CR06487081 Changes for Health Canada E2b Agencies                 **
        --*******************************************************************************************************************************
        RETURN VARCHAR2
    IS
        v_studyname     VARCHAR2 (100);
        v_seq_num       case_reporters.seq_num%TYPE;
        v_eudract       VARCHAR2 (100);
        v_report_type   lm_report_type.e2b_code%TYPE;
        l_agency_id     NUMBER;
        l_agency_id1    NUMBER;

        CURSOR c1
        IS
              SELECT lmsr.reference
                FROM lm_study_references  lmsr,
                     case_study           cs,
                     lm_clinical_ref_types lmcrt
               WHERE     cs.study_key = lmsr.study_key
                     AND cs.case_id = pi_case_id
                     AND lmsr.ref_type_id = lmcrt.ref_type_id
                     AND lmcrt.ref_type_id = 4
            ORDER BY lmsr.sort_id DESC;
    BEGIN
        IF pi_rownum = 1
        THEN
            SELECT SUBSTR (lms.study_desc, 1, 100)
              INTO v_studyname
              FROM case_reporters cr, case_study cs, lm_studies lms
             WHERE     cr.case_id = pi_case_id
                   AND cr.case_id = cs.case_id(+)
                   AND cs.study_key = lms.study_key(+)
                   AND ROWNUM = 1;

            /** Added for Health Canada E2B agencies (CR06487081) by Atin **/
            SELECT agency_id
              INTO l_agency_id
              FROM lm_regulatory_contact
             WHERE     AGENCY_NAME = 'CA Canada Marketed Health - E2B'
                   AND deleted IS NULL;

            SELECT agency_id
              INTO l_agency_id1
              FROM lm_regulatory_contact
             WHERE     AGENCY_NAME =
                       'CA Therapeutics Product Directorate-E2B'
                   AND deleted IS NULL;

            IF (l_agency_id = pi_agency_id) OR (l_agency_id1 = pi_agency_id)
            THEN
                SELECT lm_report_type.e2b_code
                  INTO v_report_type
                  FROM case_master, lm_report_type
                 WHERE     case_master.case_id = pi_case_id
                       AND case_master.rpt_type_id =
                           lm_report_type.rpt_type_id;

                IF v_report_type = 2
                THEN
                    IF v_studyname IS NOT NULL
                    THEN
                        OPEN c1;

                        FETCH c1 INTO v_eudract;

                        IF c1%FOUND
                        THEN
                            v_eudract := v_eudract || '# ';
                        ELSE
                            v_eudract := 'Unknown# ';
                        END IF;

                        CLOSE c1;

                        RETURN SUBSTR (v_eudract || v_studyname, 1, 100);
                    ELSE
                        RETURN 'Unknown# Unknown';
                    END IF;
                ELSE
                    RETURN NULL;
                END IF;
            ELSE
                /** Added for Health Canada E2B agencies (CR06487081) by Atin Ends here**/
                IF v_studyname IS NOT NULL
                THEN
                    OPEN c1;

                    FETCH c1 INTO v_eudract;

                    IF c1%FOUND
                    THEN
                        v_eudract := v_eudract || '#';
                    ELSE
                        v_eudract := '#';
                    END IF;

                    CLOSE c1;

                    RETURN SUBSTR (v_eudract || v_studyname, 1, 100);
                ELSE
                    RETURN NULL;
                END IF;
            END IF;
        /** Added for Health Canada E2B agencies (CR06487081) by Atin **/
        ELSE
            RETURN NULL;
        END IF;
    END get_studyname;

    --***************************************************************************************************
    --** Name      : f_get_current_meddra_version                                                      **
    --** Created by: Santha Athiappan                                                                  **
    --** Purpose: Returns the current version of MedDRA used to code events and indications            **
    --**                                                                                               **
    --** Inputs: none                                                                                  **
    --** Outputs: varchar2 - the current meddra version                                                **
    --**                                                                                               **
    --** Modification History:                                                                         **
    --** Santha Athiappan     26-Jan-2017  CHG0024730    Updated for defect 1765 to remove J at the    **
    --**                                                 end of the version string                     **
    --***************************************************************************************************
    FUNCTION f_get_current_meddra_version
        RETURN VARCHAR2
    IS
        l_VERSION_NUMBER   VARCHAR2 (10);
    BEGIN
        SELECT REPLACE (VERSION_NUMBER, 'J')
          INTO l_VERSION_NUMBER
          FROM cmn_profile cp, cfg_dictionaries cd
         WHERE     cp.section = 'SYSTEM'
               AND cp.key = 'AUTOE_P_E_TERM_DIC'
               AND TO_NUMBER (TRIM (VALUE)) = cd.dict_id
               AND ROWNUM = 1;

        RETURN l_VERSION_NUMBER;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END f_get_current_meddra_version;

    FUNCTION f_most_sus_drug (pi_case_id NUMBER)
        RETURN NUMBER
    IS
        l_sort_id   NUMBER;
    BEGIN
        SELECT MIN (SORT_ID)
          INTO l_sort_id
          FROM CASE_PRODUCT
         WHERE CASE_ID = pi_case_id AND DRUG_TYPE = 1;

        IF l_sort_id IS NULL
        THEN
            l_sort_id := 0;
        END IF;

        RETURN l_sort_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END f_most_sus_drug;

    --*************************************************************************************************
    --** Name      : F_PAT_NOTES                                                                     **
    --** Purpose   : Returns patient notes of specified length                                       **
    --**                                                                                             **
    --** Inputs: pi_case_id - date to be formatted                                                   **
    --**         pi_max_length - Maximum allowed length to be returned                               **
    --**         pi_check_length - 0 if length check needed, 1 if not                                **
    --** Outputs: number - patient notes                                                             **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Santha Athiappan     01-Jun-2015  CHG0024730    Updated to change the column for notes      **
    --**                                                 to case_pat_info table                      **
    --*************************************************************************************************
    FUNCTION F_PAT_NOTES (pi_case_id         NUMBER,
                          pi_max_length      NUMBER,
                          pi_check_length    NUMBER)
        RETURN CLOB
    IS
        v_condition      VARCHAR2 (32676) := NULL;
        v_notes          CLOB;
        v_notes_length   NUMBER;
        cl_notes         CLOB;
        cl_final_notes   CLOB;
        i_cnt            NUMBER;
    BEGIN
        BEGIN
            SELECT NVL (DBMS_LOB.getlength (notes), 0), notes
              INTO v_notes_length, v_notes
              FROM case_pat_info cpi
             WHERE cpi.case_id = pi_case_id;
        END;

        DBMS_LOB.createtemporary (cl_notes, TRUE, DBMS_LOB.CALL);

        IF v_notes_length > 0
        THEN
            DBMS_LOB.COPY (cl_notes, v_notes, v_notes_length);
        END IF;

        IF pi_check_length = 1
        THEN
            v_notes := cl_notes;
        ELSE
            IF v_notes_length > 0
            THEN
                IF v_notes_length <= pi_max_length
                THEN
                    v_notes := cl_notes;
                ELSE
                    DBMS_LOB.createtemporary (cl_final_notes,
                                              TRUE,
                                              DBMS_LOB.CALL);
                    DBMS_LOB.COPY (cl_final_notes, cl_notes, pi_max_length);
                    v_notes := cl_final_notes;
                    DBMS_LOB.freetemporary (cl_final_notes);
                END IF;
            ELSE
                v_notes := NULL;
            END IF;
        END IF;

        DBMS_LOB.freetemporary (cl_notes);
        RETURN v_notes;
    END F_PAT_NOTES;

    FUNCTION f_study_unblinded (pi_case_id NUMBER, pi_seq_num NUMBER)
        RETURN NUMBER
    IS
        l_rpt_type_id      NUMBER;
        l_pat_exposure     NUMBER;
        l_calssification   NUMBER;
        /*Added for CR CR06547928 by shalini */
        l_co_drug_code     ARGUS_APP.CASE_PRODUCT.CO_DRUG_CODE%TYPE;
    BEGIN
        l_pat_exposure := -1;
        l_calssification := 0;

        /*Added for CR06547928 by shalini */
        SELECT rpt_type_id
          INTO l_rpt_type_id
          FROM case_master
         WHERE case_id = pi_case_id;

        SELECT NVL (pat_exposure, -1), NVL (co_drug_code, 'NULL')
          INTO l_pat_exposure, l_co_drug_code
          FROM case_product
         WHERE case_id = pi_case_id AND seq_num = pi_seq_num;

        BEGIN
            SELECT classification_id
              INTO l_calssification
              FROM case_classifications
             WHERE case_id = pi_case_id AND classification_id = 100020;
        /*Added for CR06547928 by shalini */
        EXCEPTION
            WHEN OTHERS
            THEN
                l_calssification := 0;
        END;

        IF     l_rpt_type_id = 5
           AND l_calssification = 100020
           AND l_co_drug_code = 'Study Drug'
        THEN
            /*Added for CR06547928 by shalini */
            RETURN 3;
        ELSIF l_rpt_type_id IN (4, 5) OR (l_rpt_type_id = 100005 /*and l_calssification=100019*/
                                                                )
        THEN
            /** Report type Id 100005 added by Atin on 16-Jan-2014 for CR06621950 **/
            l_rpt_type_id := 1;
        ELSE
            l_rpt_type_id := 0;
        END IF;

        IF l_pat_exposure > 0 AND l_rpt_type_id = 1
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END f_study_unblinded;


    FUNCTION f_study_unblinded_eu (pi_case_id      NUMBER,
                                   pi_seq_num      NUMBER,
                                   pi_agency_id    NUMBER)
        --*******************************************************************************************************************************
        --** Created by: Atin Goyal                                                                                                **
        --** Creation Date: 11/20/2013                                                                                             **
        --** Purpose: Returns blinded status of the study                                                         **
        --**                                                                                                                       **
        --** Inputs: pi_case_id - case_product.case_id                                                                             **
        --**         pi_seq_num - case_product.seq_num                                                                               **
        --**         pi_agency_id - lm_regulatory_contact.agency_id                                                                                                **
        --**                                                                                                                           **
        --** Outputs: 0, 1 for unblinded and 2 - blinded                                                                                          **
        --**                                                                                                                           **
        --**                                                                                                                           **
        --** Modification History:                                                                                                     **
        --**  Atin Goyal      20-Nov-2013  CR06487081   Changes for Health Canada E2b Agencies
        --** ShaliniSingh     23-Jul-2015   CR06547928   Changes Medicinal product mapping                                              **
        --** Saba Siddiquie   06-Dec-2017  CHG1073674   Changes in Medicinal product mapping to handle spontaneous/RA/LIT(SPON) cases    **
        --** Banani Sinha     14-Dec-2017  CHG1073674   UAT issue for Medicinal product and CAP product changes
        --** Banani Sinha      19-Dec-2017 CHG1196704  Rollback changes for CHG1073674
        --** Astha Garg       24-Oct-2019  CHG1321926   Handling  the  code for health Canada issue.
        --******************************************************************************************************************
        RETURN NUMBER
    IS
        l_rpt_type_id       NUMBER;
        l_pat_exposure      NUMBER;
        l_co_drug_code      ARGUS_APP.CASE_PRODUCT.CO_DRUG_CODE%TYPE;
        l_drug_type         NUMBER;                   /*Added for CHG1321926*/
        l_agency_id         NUMBER;
        l_agency_id1        NUMBER;
        l_calssification    NUMBER;       /*Added for CR06547928 by shalini */
        l_calssification1   NUMBER;                   /*Added for CHG1321926*/
    BEGIN
        l_pat_exposure := -1;
        l_co_drug_code := 'NULL';
        l_drug_type := 0;                             /*Added for CHG1321926*/

        /** Added for Health Canada E2B agencies (CR06487081) by Atin **/
        l_calssification := 0;

        /*Added for CR06547928 by shalini */
        SELECT rpt_type_id
          INTO l_rpt_type_id
          FROM case_master
         WHERE case_id = pi_case_id;

        BEGIN
            SELECT classification_id
              INTO l_calssification
              FROM case_classifications
             WHERE     case_id = pi_case_id
                   AND classification_id = 100020
                   AND deleted IS NULL;
        /*Added for CR CR06547928 by shalini */
        EXCEPTION
            WHEN OTHERS
            THEN
                l_calssification := 0;
        END;

        /*Added for CHG1321926 starts*/
        BEGIN
            SELECT classification_id
              INTO l_calssification1
              FROM case_classifications
             WHERE     case_id = pi_case_id
                   AND classification_id = 100019
                   AND deleted IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_calssification1 := 0;
        END;

        /*Added for CHG1321926 ends*/


        /** Added for Health Canada E2B agencies (CR06487081) by Atin **/
        SELECT agency_id
          INTO l_agency_id
          FROM lm_regulatory_contact
         WHERE     AGENCY_NAME = 'CA Canada Marketed Health - E2B'
               AND deleted IS NULL;

        SELECT agency_id
          INTO l_agency_id1
          FROM lm_regulatory_contact
         WHERE     AGENCY_NAME = 'CA Therapeutics Product Directorate-E2B'
               AND deleted IS NULL;


        /*Added for CHG1321926 starts*/
        SELECT NVL (pat_exposure, -1), NVL (co_drug_code, 'NULL'), drug_type
          INTO l_pat_exposure, l_co_drug_code, l_drug_type
          FROM case_product
         WHERE     case_id = pi_case_id
               AND seq_num = pi_seq_num
               AND DELETED IS NULL;


        /*IF (l_rpt_type_id IN (4,5) OR (l_rpt_type_id=100005
            --and l_calssification=100019
          )) AND ((l_agency_id = pi_agency_id) OR (l_agency_id1 = pi_agency_id)) AND l_pat_exposure = 0 AND l_co_drug_code = 'Study Drug' THEN
          RETURN 2;*/


        IF     l_rpt_type_id = 5
           AND l_calssification = 100020
           AND l_co_drug_code = 'Study Drug'
        THEN
            RETURN 3;
        ELSIF     (   l_rpt_type_id IN (4, 100005)
                   OR (l_rpt_type_id = 5 AND l_calssification1 = 100019))
              AND l_drug_type <> 2
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    /*Added for CHG1321926 ends*/

    END f_study_unblinded_eu;

    ---shalini
    --*******************************************************************************************************************************
    --** Created by: Shalini Singh                                                                                                 **
    --** Creation Date: 5/29/2015                                                                                                  **
    --** Purpose: Returns trade name for PMS non-intervational cases                                                               **
    --**                                                                                                                           **
    --** Inputs: pi_case_id - case_product.case_id                                                                                 **
    --**         pi_seq_num - case_product.seq_num                                                                                 **
    --**         p_odc - obtain drug country                                                                                       **
    --**                                                                                                                           **
    --** Outputs: trade name                                                                                                       **
    --**                                                                                                                           **
    --**                                                                                                                           **
    --** Modification History:                                                                                                     **
    --** Shalini Singh      29-May-2013  CR06547928   Changes Medicinal product mapping                                            **
    --** Santha Athiappan   10-Apr-2016  CHG0024730   Changed specifican of L_PRODUCT_NAME to varchar to allow for char comparison **
    --** Pratima Rana       28-Nov-2016  CHG0024730   Changed UPPER(GENERIC_NAME) to TO_CHAR(UPPER(GENERIC_NAME)) to allow for char comparison **
    --** Saba Siddiquie     06-Dec-2017  CHG1073674   Applied regular expression to redact formulation from the trade names        **
    --** Banani Sinha       19-Dec-2017  CHG1196704  Rollback changes for CHG1073674                                              **
    --*******************************************************************************************************************************
    FUNCTION F_PMS_NONINT (pi_case_id    NUMBER,
                           pi_seq_num    NUMBER,
                           p_odc         VARCHAR2)
        RETURN VARCHAR2
    IS
        l_rpt_type_id    NUMBER;
        l_country_cd     lm_countries.a2%TYPE;
        l_trade_name     lm_license.trade_name%TYPE;
        L_PRODUCT_ID     CASE_PRODUCT.PRODUCT_ID%TYPE;
        L_PRODUCT_NAME   VARCHAR2 (4000);
    BEGIN
        l_trade_name := NULL;
        l_country_cd := NULL;
        L_PRODUCT_ID := 0;
        L_PRODUCT_NAME := NULL;

        BEGIN
            SELECT a2
              INTO l_country_cd
              FROM lm_countries
             WHERE     a2 = p_odc
                   AND country_id IN
                           (SELECT lss_eu_countries.country_id
                              FROM lss_eu_countries)
                   AND lm_countries.deleted IS NULL;

            SELECT DISTINCT lp.prod_name
              INTO L_PRODUCT_NAME
              FROM ARGUS_APP.LM_PRODUCT        LP,
                   ARGUS_APP.LM_LIC_PRODUCTS   LLP,
                   ARGUS_APP.LM_LICENSE        LL,
                   ARGUS_APP.LM_COUNTRIES      LC,
                   ARGUS_APP.LM_LICENSE_TYPES  LT,
                   ARGUS_APP.LM_LIC_COUNTRIES  LLC
             WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
                   AND LLP.LICENSE_ID = LL.LICENSE_ID
                   AND LL.LICENSE_ID = LLC.LICENSE_ID
                   AND LLC.COUNTRY_ID = LC.COUNTRY_ID
                   AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
                   AND LP.DELETED IS NULL
                   AND LL.DELETED IS NULL
                   AND LC.DELETED IS NULL
                   AND LT.DELETED IS NULL
                   AND LLC.DELETED IS NULL
                   AND LLP.DELETED IS NULL
                   AND UPPER (lp.prod_name) IN
                           (SELECT TO_CHAR (UPPER (GENERIC_NAME))
                              FROM case_product
                             WHERE     seq_num = pi_seq_num
                                   AND case_id = pi_case_id)
                   AND LC.A2 = 'EU'
                   AND ll.license_type_id = 4
                   AND LL.ACTIVE_MOIETY = 0
                   AND LL.WITHDRAW_DATE IS NULL
                   AND LL.AWARD_DATE <= SYSDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                L_PRODUCT_NAME := NULL;
                l_country_cd := NULL;
        END;

        IF l_country_cd IS NOT NULL AND L_PRODUCT_NAME IS NOT NULL
        THEN
            l_country_cd := 'EU';
        ELSE
            SELECT GENERIC_NAME
              INTO L_PRODUCT_NAME
              FROM case_product
             WHERE seq_num = pi_seq_num AND case_id = pi_case_id;

            l_country_cd := p_odc;
        END IF;

        BEGIN
            SELECT DISTINCT LL.TRADE_NAME
              INTO l_trade_name
              FROM ARGUS_APP.LM_PRODUCT        LP,
                   ARGUS_APP.LM_LIC_PRODUCTS   LLP,
                   ARGUS_APP.LM_LICENSE        LL,
                   ARGUS_APP.LM_COUNTRIES      LC,
                   ARGUS_APP.LM_LICENSE_TYPES  LT,
                   ARGUS_APP.LM_LIC_COUNTRIES  LLC
             WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
                   AND LLP.LICENSE_ID = LL.LICENSE_ID
                   AND LL.LICENSE_ID = LLC.LICENSE_ID
                   AND LLC.COUNTRY_ID = LC.COUNTRY_ID
                   AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
                   AND LP.DELETED IS NULL
                   AND LL.DELETED IS NULL
                   AND LC.DELETED IS NULL
                   AND LT.DELETED IS NULL
                   AND LLC.DELETED IS NULL
                   AND LLP.DELETED IS NULL
                   AND lc.a2 = l_country_cd
                   AND UPPER (lp.prod_name) = UPPER (L_PRODUCT_NAME)
                   AND ll.license_type_id = 4
                   AND LL.ACTIVE_MOIETY = 0
                   AND LL.WITHDRAW_DATE IS NULL
                   AND LL.AWARD_DATE <= SYSDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN '';                  --Populate with blank product name
        END;

        RETURN l_trade_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END F_PMS_NONINT;

--*******************************************************************************************************************************
    --** Created by: Astha Garg                                                                                                 **
    --** Creation Date: 11/29/2019                                                                                                 **
    --** Purpose: Returns trade name for PMS non-intervational cases                                                               **
    --**                                                                                                                           **
    --** Inputs: pi_case_id - case_product.case_id                                                                                 **
    --**         pi_seq_num - case_product.seq_num                                                                                 **
    --**         p_odc - obtain drug country                                                                                       **
    --**         p_reg_report_id - cmn_reg_reports.reg_report_id

    --** Outputs: trade name                                                                                                       **
    --**                                                                                                                           **
    --**                                                                                                                           **
    --** Modification History:                                                                                                     **
    --** Astha Garg         29-Nov-2019  CHG1321926    Handling  the  code for health Canada issue.                                **
    --** Astha Garg         03-Apr-2020  CHG1569008    Handling  the  code for 2 scenarios encountered in INC7624132,INC7670500    **
    --** Astha Garg        10-Jul-2020   CHG1591745    Handling  the  code for scenario- products that dont yet have a marketed    **
    --**                                               trade name and issue reported in INC7869844
    --** Karishma Gupta    21-Dec-2020   CHG1626569    Handling  the  code for scenario reported in INC8008291,INC8022627,INC8109888     **
    --**                                                                              **
    --*******************************************************************************************************************************


FUNCTION F_PMS_NONINT_AG (pi_case_id         NUMBER,
                          pi_seq_num         NUMBER,
                          p_odc              VARCHAR2,
                          p_reg_report_id    NUMBER)
   RETURN VARCHAR2
IS
   l_country_cd     lm_countries.a2%TYPE;
   l_trade_name     lm_license.trade_name%TYPE;
   L_PRODUCT_NAME   VARCHAR2 (4000);
   l_count          NUMBER;
   L_study_num      CASE_STUDY.STUDY_NUM%TYPE;
   L_REF_TYPE_ID    LM_CLINICAL_REF_TYPES.REF_TYPE_ID%TYPE;
   l_country_id     lm_countries.country_id%TYPE;

   --CHG1569008 changes starts
   l_count_eu       NUMBER;
   l_count1_eu      NUMBER;
   L_PRODUCT_ID     CASE_PRODUCT.PRODUCT_ID%TYPE;
   --CHG1569008 changes ends

   --CHG1626569 STARTS
   l_count_eu_lic   NUMBER;
   l_ag_count       NUMBER;
   l2_ag_count      NUMBER;
--CHG1626569 ENDS
BEGIN
   l_trade_name := NULL;
   l_ag_count := NULL;
   l2_ag_count := NULL;

     -- query to fetch Obtain Drug country is an EU country or not
   BEGIN
      SELECT a2
        INTO l_country_cd
        FROM lm_countries
       WHERE     a2 = p_odc
             AND country_id IN (SELECT lss_eu_countries.country_id
                                  FROM lss_eu_countries)
             AND lm_countries.deleted IS NULL;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_country_cd := NULL;
   END;


   ---CHG1591745 changes starts
   -- The query fetches the product id of the study product
   BEGIN
      SELECT cp.pat_exposure
        INTO L_PRODUCT_ID
        FROM lm_product lmp, CASE_PRODUCT CP
       WHERE     cp.pat_exposure = lmp.product_id
             AND lmp.deleted IS NULL
             AND CP.deleted IS NULL
             AND CP.SEQ_NUM = pi_seq_num
             AND CP.CASE_ID = PI_CASE_ID;
   EXCEPTION
      WHEN OTHERS
      THEN
         L_PRODUCT_ID := NULL;
   END;

   ---CHG1591745 changes ends


   --CHG1569008 changes starts
   -- the query fetch the count of marketed license of the study product that are active in EU
   BEGIN
      SELECT COUNT (*)
        INTO l_count1_eu
        FROM ARGUS_APP.LM_PRODUCT LP,
             ARGUS_APP.LM_LIC_PRODUCTS LLP,
             ARGUS_APP.LM_LICENSE LL,
             ARGUS_APP.LM_COUNTRIES LC,
             ARGUS_APP.LM_LICENSE_TYPES LT,
             ARGUS_APP.LM_LIC_COUNTRIES LLC,
             argus_app.LM_PRODUCT_FAMILY LMP
       WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
             AND LLP.LICENSE_ID = LL.LICENSE_ID
             AND LL.LICENSE_ID = LLC.LICENSE_ID
             AND LLC.COUNTRY_ID = LC.COUNTRY_ID
             AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
             AND LP.family_id = LMP.family_id
             AND LP.DELETED IS NULL
             AND LL.DELETED IS NULL
             AND LC.DELETED IS NULL
             AND LT.DELETED IS NULL
             AND LLC.DELETED IS NULL
             AND LLP.DELETED IS NULL
             AND LMP.DELETED IS NULL
             AND LLC.COUNTRY_ID = 240
             AND lp.product_id = L_PRODUCT_ID
             AND UPPER (LL.trade_name) NOT LIKE (UPPER (LMP.name || '%'))
             AND ll.license_type_id = 4
             AND LL.WITHDRAW_DATE IS NULL
             AND LL.award_date < SYSDATE;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_count1_eu := NULL;
   END;

   -- The query fetch the count of the marketed license of the study product that are active in the EU member country
   BEGIN
      SELECT COUNT (*)
        INTO l_count_eu
        FROM ARGUS_APP.LM_PRODUCT LP,
             ARGUS_APP.LM_LIC_PRODUCTS LLP,
             ARGUS_APP.LM_LICENSE LL,
             ARGUS_APP.LM_COUNTRIES LC,
             ARGUS_APP.LM_LICENSE_TYPES LT,
             ARGUS_APP.LM_LIC_COUNTRIES LLC,
             argus_app.LM_PRODUCT_FAMILY LMP
       WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
             AND LLP.LICENSE_ID = LL.LICENSE_ID
             AND LL.LICENSE_ID = LLC.LICENSE_ID
             AND LLC.COUNTRY_ID = LC.COUNTRY_ID
             AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
             AND LP.family_id = LMP.family_id
             AND LP.DELETED IS NULL
             AND LL.DELETED IS NULL
             AND LC.DELETED IS NULL
             AND LT.DELETED IS NULL
             AND LLC.DELETED IS NULL
             AND LLP.DELETED IS NULL
             AND LMP.DELETED IS NULL
             AND lp.product_id = L_PRODUCT_ID
             AND LLC.COUNTRY_ID IN (SELECT lss_eu_countries.country_id
                                      FROM lss_eu_countries
                                     WHERE DELETED IS NULL)
             AND UPPER (LL.trade_name) NOT LIKE (UPPER (LMP.name || '%'))
             AND ll.license_type_id = 4
             AND LL.WITHDRAW_DATE IS NULL
             AND LL.award_date < SYSDATE;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_count_eu := NULL;
   END;

   -- The query fetch the count for EU marketed license
   --CHG1626569 STARTS
   BEGIN
      SELECT COUNT (*)
        INTO l_count_eu_lic
        FROM (SELECT DISTINCT
                     CASE
                        WHEN REGEXP_INSTR (LL.TRADE_NAME,
                                           '1|2|3|4|5|6|7|8|9|0') > 0
                        THEN
                           LTRIM (
                              SUBSTR (
                                 LL.TRADE_NAME,
                                 1,
                                 (  (SELECT REGEXP_INSTR (
                                               LL.TRADE_NAME,
                                               '1|2|3|4|5|6|7|8|9|0')
                                       FROM DUAL)
                                  - 1)))
                        ELSE
                           LTRIM (LL.TRADE_NAME)
                     END
                FROM ARGUS_APP.LM_PRODUCT LP,
                     ARGUS_APP.LM_LIC_PRODUCTS LLP,
                     ARGUS_APP.LM_LICENSE LL,
                     ARGUS_APP.LM_COUNTRIES LC,
                     ARGUS_APP.LM_LICENSE_TYPES LT,
                     ARGUS_APP.LM_LIC_COUNTRIES LLC,
                     argus_app.LM_PRODUCT_FAMILY LMP,
                     ARGUS_APP.CASE_PRODUCT CP
               WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
                     AND LLP.LICENSE_ID = LL.LICENSE_ID
                     AND LL.LICENSE_ID = LLC.LICENSE_ID
                     AND LLC.COUNTRY_ID = LC.COUNTRY_ID
                     AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
                     AND LP.family_id = LMP.family_id
                     AND LP.DELETED IS NULL
                     AND LL.DELETED IS NULL
                     AND LC.DELETED IS NULL
                     AND LT.DELETED IS NULL
                     AND LLC.DELETED IS NULL
                     AND LLP.DELETED IS NULL
                     AND CP.DELETED IS NULL
                     AND LMP.DELETED IS NULL
                     AND LC.A2 = 'EU'
                     AND LP.PRODUCT_ID = CP.PAT_EXPOSURE
                     AND UPPER (LL.trade_name) NOT LIKE
                            (UPPER (LMP.name || '%'))
                     AND CP.SEQ_NUM = pi_seq_num
                     AND CP.CASE_ID = PI_CASE_ID
                     AND ll.license_type_id = 4
                     AND LL.WITHDRAW_DATE IS NULL
                     AND LL.award_date < SYSDATE);
   EXCEPTION
      WHEN OTHERS
      THEN
         l_count_eu_lic := NULL;
   END;

   --The queries check if the report is of CA agencies
   BEGIN
      SELECT COUNT (*)
        INTO l_ag_count
        FROM (SELECT DISTINCT CRR.AGENCY_ID
                FROM CMN_REG_REPORTS CRR
               WHERE     CRR.TRACKING_NUM =
                            (SELECT CASE_NUM
                               FROM CASE_MASTER
                              WHERE CASE_ID = pi_case_id AND DELETED IS NULL)
                     AND CRR.AGENCY_ID IN
                            (SELECT DISTINCT AGENCY_ID
                               FROM LM_REGULATORY_CONTACT
                              WHERE     AGENCY_NAME IN
                                           ('CA Canada Marketed Health - E2B')
                                    AND DELETED IS NULL)
                     AND reg_report_id = p_reg_report_id
                     AND CRR.DELETED IS NULL
                     AND CRR.DATE_SUBMISSION_DETERMINED IS NULL
                     AND CRR.DATE_SUBMITTED IS NULL);
   EXCEPTION
      WHEN OTHERS
      THEN
         l_ag_count := NULL;
   END;

   BEGIN
      SELECT COUNT (*)
        INTO l2_ag_count
        FROM (SELECT DISTINCT CRR.AGENCY_ID
                FROM CMN_REG_REPORTS CRR
               WHERE     CRR.TRACKING_NUM =
                            (SELECT CASE_NUM
                               FROM CASE_MASTER
                              WHERE CASE_ID = pi_case_id AND DELETED IS NULL)
                     AND CRR.AGENCY_ID IN
                            (SELECT DISTINCT AGENCY_ID
                               FROM LM_REGULATORY_CONTACT
                              WHERE     AGENCY_NAME IN
                                           ('CA Therapeutics Product Directorate-E2B')
                                    AND DELETED IS NULL)
                     AND reg_report_id = p_reg_report_id
                     AND CRR.DELETED IS NULL
                     AND CRR.DATE_SUBMISSION_DETERMINED IS NULL
                     AND CRR.DATE_SUBMITTED IS NULL);
   EXCEPTION
      WHEN OTHERS
      THEN
         l2_ag_count := NULL;
   END;

   --CHG1626569 ENDS

   --CHG1569008 changes ends
   --The if clause is checking if the obtain drug country is an EU member country and the product is a CAP product
   IF ( (l_country_cd IS NOT NULL) AND (l_count1_eu > 0 AND l_count_eu = 0)) --CHG1569008 changes
   THEN
      BEGIN
         IF l_count_eu_lic = 1
         THEN
            SELECT DISTINCT
                   CASE
                      WHEN REGEXP_INSTR (LL.TRADE_NAME,
                                         '1|2|3|4|5|6|7|8|9|0') > 0
                      THEN
                         LTRIM (
                            SUBSTR (
                               LL.TRADE_NAME,
                               1,
                               (  (SELECT REGEXP_INSTR (
                                             LL.TRADE_NAME,
                                             '1|2|3|4|5|6|7|8|9|0')
                                     FROM DUAL)
                                - 1)))
                      ELSE
                         LTRIM (LL.TRADE_NAME)
                   END
              INTO l_trade_name
              FROM ARGUS_APP.LM_PRODUCT LP,
                   ARGUS_APP.LM_LIC_PRODUCTS LLP,
                   ARGUS_APP.LM_LICENSE LL,
                   ARGUS_APP.LM_COUNTRIES LC,
                   ARGUS_APP.LM_LICENSE_TYPES LT,
                   ARGUS_APP.LM_LIC_COUNTRIES LLC,
                   argus_app.LM_PRODUCT_FAMILY LMP,
                   ARGUS_APP.CASE_PRODUCT CP
             WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
                   AND LLP.LICENSE_ID = LL.LICENSE_ID
                   AND LL.LICENSE_ID = LLC.LICENSE_ID
                   AND LLC.COUNTRY_ID = LC.COUNTRY_ID
                   AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
                   AND LP.family_id = LMP.family_id
                   AND LP.DELETED IS NULL
                   AND LL.DELETED IS NULL
                   AND LC.DELETED IS NULL
                   AND LT.DELETED IS NULL
                   AND LLC.DELETED IS NULL
                   AND LLP.DELETED IS NULL
                   AND CP.DELETED IS NULL
                   AND LMP.DELETED IS NULL
                   AND LC.A2 = 'EU'
                   AND LP.PRODUCT_ID = CP.PAT_EXPOSURE
                   AND UPPER (LL.trade_name) NOT LIKE
                          (UPPER (LMP.name || '%'))
                   AND CP.SEQ_NUM = pi_seq_num
                   AND CP.CASE_ID = PI_CASE_ID
                   AND ll.license_type_id = 4
                   AND LL.WITHDRAW_DATE IS NULL
                   AND LL.award_date < SYSDATE;
         --CHG1626569 STARTS
         ELSIF l_count_eu_lic > 1
         THEN
            IF (l_ag_count > 0 OR l2_ag_count > 0)
            THEN
               SELECT REF_TYPE_ID
                 INTO L_REF_TYPE_ID
                 FROM LM_CLINICAL_REF_TYPES
                WHERE     UPPER (REF_TYPE_DESC) LIKE 'HEALTH CANADA FILE #'
                      AND deleted IS NULL;


               SELECT LSR.REFERENCE
                 INTO l_trade_name
                 FROM LM_STUDY_REFERENCES LSR, CASE_STUDY CS
                WHERE     LSR.STUDY_KEY = CS.STUDY_KEY
                      AND LSR.REF_TYPE_ID = L_REF_TYPE_ID
                      AND LSR.deleted IS NULL
                      AND CS.deleted IS NULL
                      AND LSR.country_id = 38
                      AND CS.CASE_ID = pi_case_id;
            END IF;
         ELSIF l_count_eu_lic = 0
         THEN
            IF (l_ag_count > 0 OR l2_ag_count > 0)
            THEN
               SELECT LTRIM (lmp.prod_name, '*')
                 INTO l_trade_name
                 FROM lm_product lmp, CASE_PRODUCT CP
                WHERE     cp.pat_exposure = lmp.product_id
                      AND lmp.deleted IS NULL
                      AND CP.deleted IS NULL
                      AND CP.SEQ_NUM = pi_seq_num
                      AND CP.CASE_ID = PI_CASE_ID;
            END IF;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_trade_name := NULL;
      END;
   --CHG1626569 ENDS
   ELSE
      BEGIN
         SELECT COUNT (*)
           INTO l_count
           FROM (SELECT DISTINCT
                        CASE
                           WHEN REGEXP_INSTR (LL.TRADE_NAME,
                                              '1|2|3|4|5|6|7|8|9|0') > 0
                           THEN
                              LTRIM (
                                 SUBSTR (
                                    LL.TRADE_NAME,
                                    1,
                                    (  (SELECT REGEXP_INSTR (
                                                  LL.TRADE_NAME,
                                                  '1|2|3|4|5|6|7|8|9|0')
                                          FROM DUAL)
                                     - 1)))
                           ELSE
                              LTRIM (LL.TRADE_NAME)
                        END
                   FROM ARGUS_APP.LM_PRODUCT LP,
                        ARGUS_APP.LM_LIC_PRODUCTS LLP,
                        ARGUS_APP.LM_LICENSE LL,
                        ARGUS_APP.LM_COUNTRIES LC,
                        ARGUS_APP.LM_LICENSE_TYPES LT,
                        ARGUS_APP.LM_LIC_COUNTRIES LLC,
                        argus_app.LM_PRODUCT_FAMILY LMP,
                        ARGUS_APP.CASE_PRODUCT CP
                  WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
                        AND LLP.LICENSE_ID = LL.LICENSE_ID
                        AND LL.LICENSE_ID = LLC.LICENSE_ID
                        AND LLC.COUNTRY_ID = LC.COUNTRY_ID
                        AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
                        AND LP.family_id = LMP.family_id
                        AND LP.DELETED IS NULL
                        AND LL.DELETED IS NULL
                        AND LC.DELETED IS NULL
                        AND LT.DELETED IS NULL
                        AND LLC.DELETED IS NULL
                        AND LLP.DELETED IS NULL
                        AND CP.DELETED IS NULL
                        AND LMP.DELETED IS NULL
                        AND lc.a2 = p_odc
                        AND LP.PRODUCT_ID = CP.PAT_EXPOSURE
                        AND UPPER (LL.trade_name) NOT LIKE
                               (UPPER (LMP.name || '%'))
                        AND CP.SEQ_NUM = pi_seq_num
                        AND CP.CASE_ID = PI_CASE_ID
                        AND ll.license_type_id = 4
                        AND LL.WITHDRAW_DATE IS NULL
                        AND LL.award_date < SYSDATE);



         IF l_count = 1
         THEN
            SELECT DISTINCT
                   CASE
                      WHEN REGEXP_INSTR (LL.TRADE_NAME,
                                         '1|2|3|4|5|6|7|8|9|0') > 0
                      THEN
                         LTRIM (
                            SUBSTR (
                               LL.TRADE_NAME,
                               1,
                               (  (SELECT REGEXP_INSTR (
                                             LL.TRADE_NAME,
                                             '1|2|3|4|5|6|7|8|9|0')
                                     FROM DUAL)
                                - 1)))
                      ELSE
                         LTRIM (LL.TRADE_NAME)
                   END
              INTO l_trade_name
              FROM ARGUS_APP.LM_PRODUCT LP,
                   ARGUS_APP.LM_LIC_PRODUCTS LLP,
                   ARGUS_APP.LM_LICENSE LL,
                   ARGUS_APP.LM_COUNTRIES LC,
                   ARGUS_APP.LM_LICENSE_TYPES LT,
                   ARGUS_APP.LM_LIC_COUNTRIES LLC,
                   argus_app.LM_PRODUCT_FAMILY LMP,
                   ARGUS_APP.CASE_PRODUCT CP
             WHERE     LP.PRODUCT_ID = LLP.PRODUCT_ID
                   AND LLP.LICENSE_ID = LL.LICENSE_ID
                   AND LL.LICENSE_ID = LLC.LICENSE_ID
                   AND LLC.COUNTRY_ID = LC.COUNTRY_ID
                   AND LL.LICENSE_TYPE_ID = LT.LICENSE_TYPE_ID
                   AND LP.family_id = LMP.family_id
                   AND LP.DELETED IS NULL
                   AND LL.DELETED IS NULL
                   AND LC.DELETED IS NULL
                   AND LT.DELETED IS NULL
                   AND LLC.DELETED IS NULL
                   AND LLP.DELETED IS NULL
                   AND CP.DELETED IS NULL
                   AND LMP.DELETED IS NULL
                   AND lc.a2 = p_odc
                   AND LP.PRODUCT_ID = CP.PAT_EXPOSURE
                   AND UPPER (LL.trade_name) NOT LIKE
                          (UPPER (LMP.name || '%'))
                   AND CP.SEQ_NUM = pi_seq_num
                   AND CP.CASE_ID = PI_CASE_ID
                   AND ll.license_type_id = 4
                   AND LL.WITHDRAW_DATE IS NULL
                   AND LL.award_date < SYSDATE;
         -- changes CHG1591745 starts
         -- query to fetch product generic name in case where products do not yet have a marketed trade name.
         
         ELSIF (l_count = 0)
         THEN
            --CHG1626569 STARTS
            IF (l_ag_count > 0 OR l2_ag_count > 0)
            --CHG1626569 ENDS
            THEN
               SELECT LTRIM (lmp.prod_name, '*')
                 INTO l_trade_name
                 FROM lm_product lmp, CASE_PRODUCT CP
                WHERE     cp.pat_exposure = lmp.product_id
                      AND lmp.deleted IS NULL
                      AND CP.deleted IS NULL
                      AND CP.SEQ_NUM = pi_seq_num
                      AND CP.CASE_ID = PI_CASE_ID;
            END IF;
         --changes CHG1591745 ends
         
         ELSIF (l_count > 1)
         THEN
            IF (l_ag_count > 0 OR l2_ag_count > 0)
            THEN
               SELECT REF_TYPE_ID
                 INTO L_REF_TYPE_ID
                 FROM LM_CLINICAL_REF_TYPES
                WHERE     UPPER (REF_TYPE_DESC) LIKE 'HEALTH CANADA FILE #'
                      AND deleted IS NULL;


               SELECT LSR.REFERENCE
                 INTO l_trade_name
                 FROM LM_STUDY_REFERENCES LSR, CASE_STUDY CS
                WHERE     LSR.STUDY_KEY = CS.STUDY_KEY
                      AND LSR.REF_TYPE_ID = L_REF_TYPE_ID
                      AND LSR.deleted IS NULL
                      AND CS.deleted IS NULL
                      AND LSR.country_id = 38             --CHG1569008 changes
                      AND CS.CASE_ID = pi_case_id;
            END IF;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            RETURN NULL;
      END;
   END IF;

   RETURN l_trade_name;
END F_PMS_NONINT_AG;


    FUNCTION get_frm (PI_FORM_ID IN NUMBER)
        --*******************************************************************************************************************************
        RETURN VARCHAR2
    IS
        L_FORMULATION   LM_FORMULATION.FORMULATION%TYPE := NULL;
    BEGIN
        SELECT EU_DOSAGE_FORM
          INTO L_FORMULATION
          FROM LSS_LM_FORMULATION
         WHERE FORMULATION_ID = PI_FORM_ID;

        IF UPPER (L_FORMULATION) = 'UNKNOWN' OR UPPER (L_FORMULATION) = 'N/A'
        THEN
            L_FORMULATION := NULL;
        END IF;

        RETURN L_FORMULATION;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_frm;

    --*************************************************************************************************
    --** Name      : F_PRODUCT_NOTES                                                                 **
    --** Purpose   : Returns product notes of specified length                                       **
    --**                                                                                             **
    --** Inputs: pi_case_id - date to be formatted                                                   **
    --**         pi_max_length - Maximum allowed length to be returned                               **
    --**         pi_prod_seq_num - product sequence number for the product in the case               **
    --** Outputs: number - patient notes                                                             **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Santha Athiappan     01-Jun-2015  CHG0024730    Updated to change the column for notes      **
    --**                                                 to case_pat_info table                      **
    --*************************************************************************************************

    FUNCTION F_PRODUCT_NOTES (pi_case_id         NUMBER,
                              pi_prod_seq_num    NUMBER,
                              pi_max_length      NUMBER)
        RETURN VARCHAR2
    IS
        v_notes   VARCHAR2 (4000) := NULL;
    BEGIN
        SELECT DBMS_LOB.SUBSTR (NOTES, pi_max_length)
          INTO v_notes
          FROM case_product
         WHERE     case_product.case_id = pi_case_id
               AND case_product.seq_num = pi_prod_seq_num;

        RETURN v_notes;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END F_PRODUCT_NOTES;

    FUNCTION F_PARENT_NOTES (pi_case_id         NUMBER,
                             pi_max_length      NUMBER,
                             pi_check_length    NUMBER)
        RETURN CLOB
    IS
        v_med_hist_text          CLOB;
        v_med_hist_text_length   NUMBER;
        cl_med_hist_text         CLOB;
        cl_final_med_hist_text   CLOB;
    BEGIN
        BEGIN
            SELECT NVL (DBMS_LOB.getlength (med_hist_text), 0), med_hist_text
              INTO v_med_hist_text_length, v_med_hist_text
              FROM case_parent_info cpi
             WHERE cpi.case_id = pi_case_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_med_hist_text_length := 0;
                v_med_hist_text := NULL;
        END;

        DBMS_LOB.createtemporary (cl_med_hist_text, TRUE, DBMS_LOB.CALL);

        IF v_med_hist_text_length > 0
        THEN
            DBMS_LOB.COPY (cl_med_hist_text,
                           v_med_hist_text,
                           v_med_hist_text_length);
        END IF;

        IF pi_check_length = 1
        THEN
            v_med_hist_text := cl_med_hist_text;
        ELSE
            IF v_med_hist_text_length > 0
            THEN
                IF v_med_hist_text_length <= pi_max_length
                THEN
                    v_med_hist_text := cl_med_hist_text;
                ELSE
                    DBMS_LOB.createtemporary (cl_final_med_hist_text,
                                              TRUE,
                                              DBMS_LOB.CALL);
                    DBMS_LOB.COPY (cl_final_med_hist_text,
                                   cl_med_hist_text,
                                   pi_max_length);
                    v_med_hist_text := cl_final_med_hist_text;
                    DBMS_LOB.freetemporary (cl_final_med_hist_text);
                END IF;
            ELSE
                v_med_hist_text := NULL;
            END IF;
        END IF;

        DBMS_LOB.freetemporary (cl_med_hist_text);
        RETURN v_med_hist_text;
    END F_PARENT_NOTES;

    --*******************************************************************************
    --** f_sender_agency
    --**
    --** John Schroeder   CR05824924    Added E2B agencies
    --** John Schroeder   CR05837091    added ZZ_DE BfArM - E2B and ZZ_DE PEI - E2B
    --** Santha Athiappan CR06397033    Added CH Swissmedic - E2B
    --*******************************************************************************

    FUNCTION f_sender_agency (pi_agency_id NUMBER)
        RETURN NUMBER
    IS
        l_agency_name   VARCHAR2 (200);
    BEGIN
        SELECT UPPER (agency_name)
          INTO l_agency_name
          FROM lm_regulatory_contact
         WHERE agency_id = pi_agency_id;

        IF l_agency_name IN ('ZZ_DE PEI - E2B',
                             'ZZ_DE BFARM - E2B',
                             'DE BFARM',
                             'GERMAN PEI',
                             'DE PEI',
                             'DE BFARM - E2B',
                             'DE PEI - E2B')
        THEN
            RETURN 1;
        ELSIF l_agency_name IN ('CH SWISSMEDIC - E2B')
        THEN
            RETURN 2;
        ELSE
            RETURN 0;
        END IF;
    END;

    FUNCTION f_sender_comment (pi_case_id NUMBER)
        RETURN VARCHAR2
    IS
        l_comment   VARCHAR2 (4000);
    BEGIN
        SELECT DBMS_LOB.SUBSTR (c.LOCAL_COMMENT, 2000)
          INTO l_comment
          FROM case_local_eva_comment c, lm_evaluator_type l
         WHERE     case_id = pi_case_id
               AND c.EVALUATOR_TYPE_ID = l.EVALUATOR_TYPE_ID
               AND c.EVALUATOR_TYPE_ID = 2;

        RETURN l_comment;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --**********************************************************************************
    --** Name : f_other_sender_comment
    --** Description : This function supplants the f_sender comment function to allow
    --**               for generation of local comments for more than one affiliate
    --**
    --** Santha Athiappan  10-Sep-2012 CR06397033   Added new function for Swiss agency
    --** Borsha Bordoloi   1-Oct-2014  CR06709073   Commneted German local evaluator comment
    --** Charu Goel   18-Feb-2014 CR06802805   Changed for Canadian Agencies
    --**********************************************************************************

    FUNCTION f_other_sender_comment (pi_case_id NUMBER, pi_agency_id NUMBER)
        RETURN VARCHAR2
    IS
        l_rpt_type_id      NUMBER;                  ------Added for CR06802805
        l_comment          VARCHAR2 (4000);
        l_agency_name      VARCHAR2 (200);
        l_evaluator_type   VARCHAR2 (200);
    BEGIN
        ------Added for CR06802805
        SELECT rpt_type_id
          INTO l_rpt_type_id
          FROM case_master
         WHERE case_id = pi_case_id;

        ------Added for CR06802805
        SELECT UPPER (agency_name)
          INTO l_agency_name
          FROM lm_regulatory_contact
         WHERE agency_id = pi_agency_id;

        --if l_agency_name in ('ZZ_DE PEI - E2B','ZZ_DE BFARM - E2B','DE BFARM', 'GERMAN PEI', 'DE PEI','DE BFARM - E2B', 'DE PEI - E2B') then
        --  l_evaluator_type := 'German';  -- Commneted German local evaluator comment for CR# CR06709073
        IF l_agency_name = 'CH SWISSMEDIC - E2B'
        THEN
            l_evaluator_type := 'Swiss';
        ELSE
            l_evaluator_type := NULL;
        END IF;

        IF l_evaluator_type IS NOT NULL
        THEN
            SELECT DBMS_LOB.SUBSTR (clec.LOCAL_COMMENT, 2000)
              INTO l_comment
              FROM case_local_eva_comment  clec,
                   lm_evaluator_type       let,
                   lm_sites                ls
             WHERE     clec.case_id = pi_case_id
                   AND clec.evaluator_type_id = let.evaluator_type_id
                   AND let.evaluator_type = l_evaluator_type
                   AND let.site_id = ls.site_id
                   AND ls.site_desc = 'Lilly';
        ELSE
            ------Added for CR06802805
            IF     l_agency_name IN
                       ('CA CANADA MARKETED HEALTH - E2B',
                        'CA THERAPEUTICS PRODUCT DIRECTORATE-E2B')
               AND l_rpt_type_id IN (1,
                                     2,
                                     3,
                                     5,
                                     100004)
            THEN
                l_comment := NULL;
            ELSE
                ------Added for CR06802805
                SELECT DBMS_LOB.SUBSTR (cc.comment_txt, 2000)
                  INTO l_comment
                  FROM case_comments cc
                 WHERE cc.case_id = pi_case_id;
            END IF;
        END IF;

        RETURN l_comment;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION f_ct_case_no_drug_selected (pi_case_id         NUMBER,
                                         pi_co_drug_code    VARCHAR2,
                                         pi_pat_exposure    NUMBER)
        RETURN NUMBER
    IS
        l_rpt_type_id   NUMBER;
    BEGIN
        SELECT rpt_type_id
          INTO l_rpt_type_id
          FROM case_master
         WHERE case_id = pi_case_id;

        IF l_rpt_type_id NOT IN (4, 5)
        THEN
            RETURN 0;
        END IF;

        IF pi_co_drug_code = 'Study Drug' AND NVL (pi_pat_exposure, 0) = 0
        THEN
            /** changed nvl condition  (replaced -1 by 0) for blinded studies as per current EU requirements under CR06487081 by Atin **/
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END f_ct_case_no_drug_selected;

    FUNCTION F_GET_PARENT_AGE (pi_case_id INTEGER)
        RETURN NUMBER
    IS
        ln_return        NUMBER;
        ln_age           NUMBER;
        ln_age_unit_id   NUMBER;
        ln_e2b_code      NUMBER;
    BEGIN
        SELECT cpi.age, cpi.age_unit_id, lu.e2b_code
          INTO ln_age, ln_age_unit_id, ln_e2b_code
          FROM case_parent_info cpi, lm_age_units lu
         WHERE case_id = pi_case_id AND cpi.age_unit_id = lu.age_unit_id;

        IF     NVL (ln_age, 0) > 0
           AND NVL (ln_age_unit_id, 0) > 0
           AND ln_e2b_code IS NOT NULL
        THEN
            IF ln_age_unit_id = 5
            THEN                                                      -- Years
                RETURN ln_age;
            ELSIF ln_age_unit_id = 7
            THEN                                                    -- Seconds
                RETURN ROUND (ln_age / (60 * 60 * 24 * 365), 0);
            ELSIF ln_age_unit_id = 6
            THEN                                                    -- Minutes
                RETURN ROUND (ln_age / (60 * 24 * 365), 0);
            ELSIF ln_age_unit_id = 1
            THEN                                                      -- Hours
                RETURN ROUND (ln_age / (24 * 365), 0);
            ELSIF ln_age_unit_id = 2
            THEN                                                       -- Days
                RETURN ROUND (ln_age / (365), 0);
            ELSIF ln_age_unit_id = 3
            THEN                                                      -- weeks
                RETURN ROUND (ln_age / (52), 0);
            ELSIF ln_age_unit_id = 4
            THEN                                                     -- Months
                RETURN ROUND (ln_age / (12), 0);
            ELSIF ln_age_unit_id = 8
            THEN                                                  -- Trimester
                RETURN ROUND (ln_age / (4), 0);
            END IF;
        END IF;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_PARENT_AGE;

    FUNCTION f_get_patient_age (pi_case_id INTEGER)
        RETURN NUMBER
    IS
        ln_return        NUMBER;
        ln_age           NUMBER;
        ln_age_unit_id   NUMBER;
        ln_e2b_code      NUMBER;
    BEGIN
        SELECT cpi.pat_age, cpi.age_unit_id, lu.e2b_code
          INTO ln_age, ln_age_unit_id, ln_e2b_code
          FROM case_pat_info cpi, lm_age_units lu
         WHERE case_id = pi_case_id AND cpi.age_unit_id = lu.age_unit_id(+);

        IF NVL (ln_age, 0) > 0
        THEN
            RETURN ln_age;
        END IF;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END f_get_patient_age;

    FUNCTION f_get_patient_age_unit (pi_case_id INTEGER)
        RETURN NUMBER
    IS
        ln_return        NUMBER;
        ln_age           NUMBER;
        ln_age_unit_id   NUMBER;
        ln_e2b_code      NUMBER;
    BEGIN
        SELECT cpi.pat_age, cpi.age_unit_id, lu.e2b_code
          INTO ln_age, ln_age_unit_id, ln_e2b_code
          FROM case_pat_info cpi, lm_age_units lu
         WHERE case_id = pi_case_id AND cpi.age_unit_id = lu.age_unit_id;

        IF ln_e2b_code IS NOT NULL
        THEN
            RETURN ln_e2b_code;
        END IF;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END f_get_patient_age_unit;

    --*************************************************************************************************
    --** Name      : f_medically_confirm                                                             **
    --** Created by: Santha Athiappan                                                                **
    --** Purpose: Returns e2b code for the medicallyconfirm element                                  **
    --**                                                                                             **
    --** Inputs: pi_case_id - case_id                                                                **
    --** Outputs: number - e2bcode for medically confirmed or null                                   **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Santha Athiappan    26-Nov-2012  CR06428064    Created                                      **
    --** Santha Athiappan     17-Jun-2013  CR06537806    Merging changes from EU GVP into the COE     **
    --**                                                code line to ensure that the Qualification   **
    --**                                                changes are implemented alongwith the GVP    **
    --**                                                changes.                                     **
    --** Santha Athiappan    18-Jun-2013  CR06538299    Updating function to accomodate multiple HCP **
    --**                                                reporters in a case where the intial reporter**
    --**                                                is a Consumer                                **
    --*************************************************************************************************

    FUNCTION f_medically_confirm (PI_CASE_ID NUMBER)
        RETURN INTEGER
    IS
        l_e2b_code   INTEGER;
        C_YES        INTEGER := 1;
        C_NO         INTEGER := 2;
    BEGIN
        BEGIN
            SELECT C_NO
              INTO l_e2b_code
              FROM case_master cm, case_reporters cr1
             WHERE     cm.case_id = pi_case_id
                   AND cm.case_id = cr1.case_id
                   AND NVL (cr1.hcp_flag, 0) <> 1
                   AND cr1.primary_contact = 1
                   AND cr1.deleted IS NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_e2b_code := NULL;
        END;

        IF l_e2b_code = C_NO
        THEN
            BEGIN
                --PROJECT R3ADY------RV--
                SELECT DISTINCT
                       (DECODE (cm.medically_confirm,
                                0, C_NO,
                                1, C_YES,
                                NULL))
                  INTO l_e2b_code
                  FROM case_master cm, case_reporters cr2
                 WHERE     cm.case_id = pi_case_id
                       AND cm.case_id = cr2.case_id
                       AND cr2.hcp_flag = 1
                       AND NVL (cr2.primary_contact, 0) <> 1
                       AND cr2.deleted IS NULL;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;
        END IF;

        RETURN l_e2b_code;
    END;

    FUNCTION get_DRGTY (pi_CASE_ID IN NUMBER, PI_SEQ_NUM IN NUMBER)
        RETURN NUMBER
    IS
        i_drug_type     NUMBER;
        i_interaction   NUMBER;
    BEGIN
        SELECT DRUG_TYPE
          INTO i_drug_type
          FROM CASE_PRODUCT
         WHERE CASE_ID = pi_CASE_ID AND SEQ_NUM = pi_seq_num;

        SELECT NVL (INTERACTION, -1)
          INTO i_interaction
          FROM CASE_PROD_DRUGS
         WHERE CASE_ID = pi_CASE_ID AND SEQ_NUM = pi_seq_num;

        IF i_drug_type = 1 AND i_interaction = 0
        THEN
            RETURN 1;
        ELSIF i_drug_type = 2 AND i_interaction = 0
        THEN
            RETURN 2;
        ELSIF i_drug_type = 3
        THEN
            RETURN 2;
        ELSIF i_drug_type IN (1, 2) AND i_interaction = 1
        THEN
            RETURN 3;
        ELSE
            RETURN NULL;
        END IF;
    END;

    FUNCTION f_chk_narrative (pi_CASE_ID           IN NUMBER,
                              pi_max_len           IN NUMBER,
                              pi_include_spanish   IN INTEGER,
                              pi_lang_id           IN NUMBER)
        --*******************************************************************************************************************************
        --** Created by: David Charlton                                                                                                **
        --** Creation Date: 04/03/2008                                                                                                 **
        --** Purpose: Returns narrative, including Spanish narrative where appropriate                                                 **
        --**                                                                                                                           **
        --** Inputs: pi_case_id - case_id, pi_max_len - maximum number of characters to be returned,                                   **
        --**         pi_include_spanish - boolean, pi_lang_id - relevant language_id                                                   **
        --** Outputs: narrative string - if destination is Spain, include entire Spanish narrative first, then the English narrative   **
        --**          until the maximum length.                                                                                        **
        --**                                                                                                                           **
        --** Modification History:                                                                                                     **
        --**  John Schroeder   19-Mar-2009  CR05619434                                                                                 **
        --** Purpose:  change output variables from Varchar2 to CLOB                                                                   **
        --**                                                                                                                           **
        --**  Sujay Aggarwal   05-Sep-2012  CR06337448                                                                                 **
        --** Purpose:  Changes to ensure that Report generates irrespective of presence of Spanish Narrative                           **
        --*******************************************************************************************************************************
        RETURN CLOB
    IS
        l_field_id        NUMBER := 0;
        l_spanish_narr    CLOB := NULL;
        l_english_narr    CLOB := NULL;
        l_narr            CLOB := NULL;
        tmp_narr          CLOB;
        l_count           NUMBER := 0;
        no_english_narr   EXCEPTION;
    BEGIN
        SELECT cf.field_id
          INTO l_field_id
          FROM argus_app.cmn_fields cf
         WHERE     UPPER (cf.COLUMN_NAME) = 'NARRATIVE'
               AND UPPER (cf.TABLE_NAME) = 'CASE_NARRATIVE';

        SELECT esm_utl.f_chk_narrative (pi_case_id, pi_max_len)
          INTO l_english_narr
          FROM DUAL;

        IF l_english_narr IS NULL
        THEN
            RAISE no_english_narr;
        END IF;

        SELECT COUNT (*)
          INTO l_count
          FROM case_language cl
         WHERE     cl.case_id = pi_case_id
               AND cl.LANGUAGE_ID = pi_lang_id
               AND cl.FIELD_ID = l_field_id
               AND DBMS_LOB.getlength (cl.text) != 0;

        IF (pi_include_spanish > 0 AND l_count > 0)
        THEN
            SELECT cl.text || CHR (10)
              INTO l_spanish_narr
              FROM case_language cl
             WHERE     cl.case_id = pi_case_id
                   AND cl.LANGUAGE_ID = pi_lang_id
                   AND cl.FIELD_ID = l_field_id
                   AND DBMS_LOB.getlength (cl.text) != 0;

            DBMS_LOB.APPEND (l_spanish_narr, l_english_narr);
            DBMS_LOB.createtemporary (tmp_narr, TRUE, DBMS_LOB.CALL);
            DBMS_LOB.COPY (tmp_narr,
                           l_spanish_narr,
                           pi_max_len,
                           1,
                           1);
            l_narr := tmp_narr;
            DBMS_LOB.freetemporary (tmp_narr);
        ELSE
            l_narr := l_english_narr;
        END IF;

        RETURN l_narr;
    END;

    FUNCTION f_chk_narrative_ema (pi_CASE_ID           IN NUMBER,
                                  pi_max_len           IN NUMBER,
                                  pi_include_spanish   IN INTEGER,
                                  pi_lang_id           IN NUMBER)
        --*******************************************************************************************************************************
        --** Created by: Nawaz Mehdi                                                                                                   **
        --** Creation Date: 01-NOV-2017                                                                                                **
        --** Purpose: Returns narrative, including Spanish narrative where agency is 'EU EMA - POSTMKT - E2B' and case country is      **
        --**          SPAIN.                                                                                                           **
        --**                                                                                                                           **
        --** Modification History: New function created for CHG1156084.                                                                **
        --** Inputs: pi_case_id - case_id, pi_max_len - maximum number of characters to be returned,                                   **
        --**         pi_include_spanish - boolean, pi_lang_id - relevant language_id                                                   **
        --** Outputs: narrative string - if destination is Spain, include entire Spanish narrative first, then the English narrative   **
        --**          until the maximum length.                                                                                        **
        --*******************************************************************************************************************************
        RETURN CLOB
    IS
        l_field_id        NUMBER := 0;
        l_spanish_narr    CLOB := NULL;
        l_english_narr    CLOB := NULL;
        l_narr            CLOB := NULL;
        tmp_narr          CLOB;
        l_count           NUMBER := 0;
        l_case_count      NUMBER := 0;
        no_english_narr   EXCEPTION;
    BEGIN
        SELECT cf.field_id
          INTO l_field_id
          FROM argus_app.cmn_fields cf
         WHERE     UPPER (cf.COLUMN_NAME) = 'NARRATIVE'
               AND UPPER (cf.TABLE_NAME) = 'CASE_NARRATIVE';

        SELECT esm_utl.f_chk_narrative (pi_case_id, pi_max_len)
          INTO l_english_narr
          FROM DUAL;

        IF l_english_narr IS NULL
        THEN
            RAISE no_english_narr;
        END IF;

        SELECT COUNT (*)
          INTO l_count
          FROM case_language cl
         WHERE     cl.case_id = pi_case_id
               AND cl.LANGUAGE_ID = pi_lang_id
               AND cl.FIELD_ID = l_field_id
               AND DBMS_LOB.getlength (cl.text) != 0;

        SELECT COUNT (*)
          INTO l_case_count
          FROM case_master cm
         WHERE cm.case_id = pi_case_id AND country_id = 195;

        IF (pi_include_spanish > 0 AND l_count > 0 AND l_case_count > 0)
        THEN
            SELECT cl.text || CHR (10)
              INTO l_spanish_narr
              FROM case_language cl
             WHERE     cl.case_id = pi_case_id
                   AND cl.LANGUAGE_ID = pi_lang_id
                   AND cl.FIELD_ID = l_field_id
                   AND DBMS_LOB.getlength (cl.text) != 0;

            DBMS_LOB.APPEND (l_spanish_narr, l_english_narr);
            DBMS_LOB.createtemporary (tmp_narr, TRUE, DBMS_LOB.CALL);
            DBMS_LOB.COPY (tmp_narr,
                           l_spanish_narr,
                           pi_max_len,
                           1,
                           1);
            l_narr := tmp_narr;
            DBMS_LOB.freetemporary (tmp_narr);
        ELSE
            l_narr := l_english_narr;
        END IF;

        RETURN l_narr;
    END;

    --*************************************************************************************************
    --** Name      : F_DATE_IN_CHAR                                                                  **
    --** Created by: Santha Athiappan                                                                **
    --** Purpose: Returns date in DD-Mon-YYYY format                                                 **
    --**                                                                                             **
    --** Inputs: pi_date - date to be formatted                                                      **
    --** Outputs: number - e2bcode for medically confirmed or null                                   **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Santha Athiappan     01-Jun-2015  CHG0024730    Created                                     **
    --*************************************************************************************************

    FUNCTION F_DATE_IN_CHAR (pi_date DATE)
        RETURN VARCHAR2
    IS
        v_retval   VARCHAR2 (20);
    BEGIN
        SELECT TO_CHAR (pi_date, 'DD-MON-YYYY') INTO v_retval FROM DUAL;

        RETURN v_retval;
    END;

    --*************************************************************************************************
    --** Name      : F_FULL_DATE_IN_CHAR                                                             **
    --** Created by: Santha Athiappan                                                                **
    --** Purpose: Returns date in DD-Mon-YYYY HH24:MI:SS format                                      **
    --**                                                                                             **
    --** Inputs: pi_date - date to be formatted                                                      **
    --** Outputs: number - e2bcode for medically confirmed or null                                   **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Santha Athiappan     01-Jun-2015  CHG0024730    Created                                     **
    --*************************************************************************************************

    FUNCTION F_FULL_DATE_IN_CHAR (pi_date DATE)
        RETURN VARCHAR2
    IS
        v_retval   VARCHAR2 (20);
    BEGIN
        SELECT TO_CHAR (pi_date, 'DD-MON-YYYY HH24:MI:SS')
          INTO v_retval
          FROM DUAL;

        RETURN v_retval;
    END;

    --*************************************************************************************************
    --** Name:       F_GET_DOCUMENTLIST                                                              **
    --**                                                                                             **
    --** Created by: Surabhi Sharma                                                                  **
    --**                                                                                             **
    --** Creation date: 28/05/2015                                                                   **
    --**                                                                                             **
    --** Purpose:  The Out-of-Box functionality is to map the field.                                 **
    --** The change is to map it to 'Description' for PMDA report if the attachment classification   **
    --** is checked as E2B additional doc in console.                                                **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**         PI_TYPE - 0 for NOTES field, 1 for NOTES_J field                                    **
    --**                                                                                             **
    --** Outputs: VARCHAR2(200), Description with delimited by comma                                 **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Surabhi Sharma     28-May-2015  CHG0024730  Created                                         **
    --** Sharad Kumar       07-Sep-2016  CHG0024730  Updated for coding standards                    **
    --** Sharad Kumar       01-Nov-2016  CHG0024730  Updated to return notesj if english             **
    --**                                             classification is Literature and NotesJ         **
    --**                                             is populated                                    **
    --*************************************************************************************************

    FUNCTION F_GET_DOCUMENTLIST (PI_CASE_ID IN NUMBER, PI_TYPE IN NUMBER)
        RETURN VARCHAR2
    IS
        PV_DOCUMENT_LIST   VARCHAR2 (200);
    BEGIN
        IF PI_TYPE = 0
        THEN
            SELECT SUBSTR (
                       LISTAGG (NOTES, ',') WITHIN GROUP (ORDER BY NOTES),
                       1,
                       200)
              INTO PV_DOCUMENT_LIST
              FROM CASE_NOTES_ATTACH
             WHERE CASE_ID = PI_CASE_ID;
        ELSE
            SELECT SUBSTR (
                       LISTAGG (NOTES_J, ',') WITHIN GROUP (ORDER BY NOTES_J),
                       1,
                       200)
                       NOTES
              INTO PV_DOCUMENT_LIST
              FROM (SELECT CASE
                               WHEN     CASE_NOTES_ATTACH.CLASSIFICATION IN
                                            (SELECT CLASSIFICATION_ID
                                               FROM LM_CLASSIFICATION
                                              WHERE CLASSIFICATION =
                                                    'Literature')
                                    AND NOTES_J IS NOT NULL
                               THEN
                                   NOTES_J
                               ELSE
                                   NULL
                           END
                               NOTES_J
                      FROM CASE_NOTES_ATTACH, LM_CLASSIFICATION
                     WHERE     CASE_ID = PI_CASE_ID
                           AND CASE_NOTES_ATTACH.CLASSIFICATION =
                               LM_CLASSIFICATION.CLASSIFICATION_ID
                           AND E2B_ADDITIONAL_DOC = 1);
        END IF;

        RETURN PV_DOCUMENT_LIST;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_DOCUMENTLIST;

    --*************************************************************************************************
    --** Name:       F_GET_ADDITIONALDOCUMENT                                                        **
    --**                                                                                             **
    --** Created by: Surabhi Sharma                                                                  **
    --**                                                                                             **
    --** Creation date: 28/05/2015                                                                   **
    --**                                                                                             **
    --** Purpose:  The Out-of-Box functionality is to map the field to 1(YES) if                     **
    --**          'E2B Additional Doc is enabled else 0(NO)' .                                       **
    --** The change is to map it to 1(YES) for PMDA report if the attachment classification          **
    --** is' Literature' and Japanese description is available else map it to 0(NO)                  **
    --** is checked as E2B additional doc in console.                                                **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**                                                                                             **
    --** Outputs: VARCHAR2(200),1(YES) or 0(NO)                                                      **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Surabhi Sharma     28-May-2015 CHG0024730  Created                                          **
    --** Sharad Kumar       07-Sep-2016 CHG0024730  Updated for coding standards                     **
    --** Santha Athiappan   30-Jun-2017    8.x     temp update to accomadte ASE_NOTES_ATTACH.NOTES_J **
    --**                                           change fom varchar to clob in 8.x                 **
    --*************************************************************************************************

    FUNCTION F_GET_ADDITIONALDOCUMENT (PI_CASE_ID IN NUMBER)
        RETURN VARCHAR2
    IS
        v_ADDITIONAL_DOCUMENT_LIST   VARCHAR2 (200);
        v_ADDITIONALDOCUMENT_OUT     NUMBER;
        v_CLASSIFICATION             NUMBER;
        v_ADDITIONALDOCUMENT         NUMBER;
    BEGIN
        SELECT DECODE (
                   INSTR (
                       SUBSTR (
                           LISTAGG (ADDITIONALDOCUMENT, ',')
                               WITHIN GROUP (ORDER BY ADDITIONALDOCUMENT),
                           1,
                           200),
                       '1'),
                   0, 2,
                   NULL, 2,
                   1)
                   ADDITIONALDOCUMENT
          INTO v_ADDITIONAL_DOCUMENT_LIST
          FROM (SELECT DECODE (
                           LM_CLASSIFICATION.CLASSIFICATION_J,
                           '??', DECODE (
                                     NVL (
                                         TO_CHAR (CASE_NOTES_ATTACH.NOTES_J),
                                         '~'),
                                     '~', 2,
                                     1),
                           DECODE (
                               LM_CLASSIFICATION.CLASSIFICATION,
                               'Literature', DECODE (
                                                 NVL (
                                                     TO_CHAR (
                                                         CASE_NOTES_ATTACH.NOTES_J),
                                                     '~'),
                                                 '~', 2,
                                                 1),
                               1))
                           ADDITIONALDOCUMENT
                  FROM CASE_NOTES_ATTACH, LM_CLASSIFICATION
                 WHERE     CASE_ID = PI_CASE_ID
                       AND CASE_NOTES_ATTACH.CLASSIFICATION =
                           CLASSIFICATION_ID
                       AND E2B_ADDITIONAL_DOC = 1);

        RETURN v_ADDITIONAL_DOCUMENT_LIST;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_ADDITIONALDOCUMENT;

    /***********************************************************************************************************************************
        ** Name:       F_GET_RESULTSTESTSPROCEDURES                                                                                       **
        **                                                                                                                                **
        ** Created by: Sharad Kumar                                                                                                       **
        **                                                                                                                                **
        ** Creation date: 13-Jul-/2016                                                                                                    **
        **                                                                                                                                **
        ** Purpose:                                                                                                                       **
        **     1) For Null Test Date, return lab data in the format:                                                                      **
        **        ???????? – ???:<test name>,<unit>:,??????:<low>,??????:<high>, (?? <xxx><unit>) <relevant Test>                   **
        **     2) For the test having duplicate test date return lab data in the format:                                                  **
        **        ???????? – ???:<test name>,<unit>:,??????:<low>,??????:<high>, (?? <xxx><unit>) <relevant Test>                   **
        **     3) If there is no Lab Data and no Relevant Test the return the text ?????                                                 **
        **                                                                                                                                **
        ** Inputs: PI_CASE_ID - It is used to input Case ID                                                                               **
        **        PI_RPT_CATEGORY - It is used to input Report Category                                                                   **
        **                                                                                                                                **
        ** Outputs: VARCHAR2(2000)                                                                                                        **
        **                                                                                                                                **
        ** Modification History:                                                                                                          **
        ** Sharad Kumar       13-Jul-2016  CHG0024730   Created                                                                           **
        ** Sharad Kumar       05-Aug-2016  CHG0024730   1) For the test having duplicate test date return lab data in the format:         **
        **        ??????? – ???: – ???:<test name>,<unit>:,??????:<low>,??????:<high>, (?? <xxx><unit>) <relevant Test>            **
        ** Sharad Kumar       02-Jan-2017  CHG0024730   fixed to return max of 2000 japanese characters                                   **
        ************************************************************************************************************************************/

    FUNCTION F_GET_RESULTSTESTSPROCEDURES (PI_CASE_ID        IN NUMBER,
                                           PI_RPT_CATEGORY   IN VARCHAR2)
        RETURN CLOB
    IS
        --Local Variables
        l_rel_tests              argus_app.case_pat_tests.rel_tests%TYPE := NULL;
        l_found_rel_tests        BOOLEAN := FALSE;
        l_found_lab_data         BOOLEAN := FALSE;
        l_found_lab_data_date    BOOLEAN := FALSE;
        l_reltestsprocedures     VARCHAR2 (32767 CHAR) := NULL;
        l_r_reltestsprocedures   CLOB := NULL;   --varchar2(32767 char):=null;

        --Cursors
        --cursor to get text for relevant test
        CURSOR c_case_pat_tests (
            p_case_id    NUMBER)
        IS
            SELECT CASE
                       WHEN DBMS_LOB.SUBSTR (rel_tests, 100, 1) IS NULL
                       THEN
                           NULL
                       WHEN LENGTH (
                                DBMS_LOB.SUBSTR (TRIM (rel_tests), 100, 1)) =
                            0
                       THEN
                           NULL
                       ELSE
                           rel_tests
                   END
                       c_rel_tests,
                   CASE
                       WHEN DBMS_LOB.SUBSTR (rel_tests_j, 100, 1) IS NULL
                       THEN
                           NULL
                       WHEN LENGTH (
                                DBMS_LOB.SUBSTR (TRIM (rel_tests_j), 100, 1)) =
                            0
                       THEN
                           NULL
                       ELSE
                           rel_tests_j
                   END
                       c_rel_tests_j
              FROM argus_app.case_pat_tests cpt
             WHERE cpt.rel_test_id = p_case_id AND cpt.deleted IS NULL;

        --cursor to get case lab data
        CURSOR c_case_lab_data (
            p_case_id    NUMBER)
        IS
            SELECT cldi.reltestsprocedures,
                   NVL (lab_data.lab_data_exists, 0) lab_data_exists
              FROM (  SELECT RTRIM (
                                 XMLAGG (XMLELEMENT (
                                             e,
                                                CASE
                                                    WHEN cld.test_date
                                                             IS NOT NULL
                                                    THEN
                                                        '??????? - ???:'
                                                    ELSE
                                                        '???????? - ???:'
                                                END
                                             || NVL (cld.test_reptd_j,
                                                     cld.test_reptd)
                                             || ','
                                             || cld.unit
                                             || ':,??????:'
                                             || cld.norm_low
                                             || ',??????:'
                                             || cld.norm_high
                                             || ', (?? '
                                             || NVL (cld.results_j,
                                                     cld.results)
                                             || cld.unit
                                             || ')'
                                             || ';') ORDER BY cld.sort_id).EXTRACT (
                                     '//text()'),
                                 ';')
                                 reltestsprocedures,
                             case_id
                        FROM argus_app.case_lab_data cld
                       WHERE     cld.case_id = p_case_id
                             AND cld.deleted IS NULL
                             AND (   cld.test_date IS NULL
                                  /*Check for null test Dates*/
                                  OR cld.seq_num IN
                                         ( /* Check if a test has duplicate test dates */
                                          SELECT seq_num
                                            FROM argus_app.case_lab_data cldia
                                                 JOIN
                                                 (  SELECT cldii.test_date,
                                                           NVL (
                                                               cldii.test_reptd_j,
                                                               cldii.test_reptd)
                                                               lab_test_name_j,
                                                           COUNT (1)
                                                      FROM argus_app.case_lab_data
                                                           cldii
                                                     WHERE     cldii.case_id =
                                                               p_case_id
                                                           AND cldii.test_date
                                                                   IS NOT NULL
                                                           AND cldii.deleted
                                                                   IS NULL
                                                    HAVING COUNT (1) > 1
                                                  GROUP BY cldii.test_date,
                                                           NVL (
                                                               cldii.test_reptd_j,
                                                               cldii.test_reptd))
                                                 cldib
                                                     ON (    cldia.test_date =
                                                             cldib.test_date
                                                         AND NVL (
                                                                 cldia.test_reptd_j,
                                                                 cldia.test_reptd) =
                                                             cldib.lab_test_name_j)
                                           WHERE     cldia.test_date
                                                         IS NOT NULL
                                                 AND cldia.case_id = p_case_id
                                                 AND cldia.deleted IS NULL))
                    GROUP BY case_id) cldi
                   FULL OUTER JOIN
                   (  SELECT case_id, COUNT (case_id) lab_data_exists
                        FROM argus_app.case_lab_data
                       WHERE     deleted IS NULL
                             AND test_date IS NOT NULL
                             AND case_id = p_case_id
                    GROUP BY case_id) lab_data
                       ON (lab_data.case_id = cldi.case_id)
                   FULL OUTER JOIN (SELECT 1 FROM DUAL) dummy ON (1 = 1);
    BEGIN
        IF PI_RPT_CATEGORY NOT IN ('E',
                                   'F',
                                   'G',
                                   'L',
                                   'M',
                                   'N',
                                   'O',
                                   'P')
        THEN
            l_found_rel_tests := FALSE;
            /*setting the variable to false to indicate no relevant test text found.*/
            l_rel_tests := NULL;

            /*setting the variable to null to indicate no relevant test text exists.*/
            --Relevant test exists
            FOR get_tests IN c_case_pat_tests (PI_CASE_ID)
            LOOP
                l_found_rel_tests := TRUE;

                IF get_tests.c_rel_tests_j IS NOT NULL
                THEN
                    l_rel_tests := get_tests.c_rel_tests_j;
                ELSIF get_tests.c_rel_tests IS NOT NULL
                THEN
                    l_rel_tests := get_tests.c_rel_tests;
                ELSE
                    l_rel_tests := NULL;
                    l_found_rel_tests := FALSE;
                END IF;
            END LOOP;

            --Check if Lab data exists
            l_found_lab_data := FALSE;
            /*setting the variable to false to indicate no lab data found*/
            l_found_lab_data_date := FALSE;
            /*setting the variable to false to indicate lab data with date not found*/
            l_reltestsprocedures := NULL;

            /*seting the variable to null to indicate no lab data*/
            FOR get_lab_data IN c_case_lab_data (PI_CASE_ID)
            LOOP
                IF get_lab_data.reltestsprocedures IS NOT NULL
                THEN
                    l_found_lab_data := TRUE;
                    l_reltestsprocedures := get_lab_data.reltestsprocedures;
                ELSE
                    l_found_lab_data_date :=
                        CASE
                            WHEN get_lab_data.lab_data_exists > 0 THEN TRUE
                            ELSE FALSE
                        END;
                    l_found_lab_data := FALSE;
                    l_reltestsprocedures := NULL;
                END IF;
            END LOOP;

            --setting the return value
            --scenario1: when no text for relevant tests and not lab data
            IF     l_found_rel_tests = FALSE
               AND l_found_lab_data = FALSE
               AND l_found_lab_data_date = FALSE
            THEN
                l_r_reltestsprocedures := '?????';
            --scenario2: when text exists for relevant tests and no lab data
            ELSIF     l_found_rel_tests = TRUE
                  AND l_found_lab_data = FALSE
                  AND l_found_lab_data_date = FALSE
            THEN
                l_r_reltestsprocedures := l_rel_tests;
            --scenario2: when no text for relevant tests and lab data exists
            ELSIF l_found_rel_tests = FALSE AND l_found_lab_data = TRUE
            THEN
                l_r_reltestsprocedures := l_reltestsprocedures;
            --scenario3: when text exists for relevant tests and lab data exists with multiple same date
            ELSIF l_found_rel_tests = TRUE AND l_found_lab_data = TRUE
            THEN
                l_r_reltestsprocedures :=
                    l_reltestsprocedures || ' ' || l_rel_tests;
            --scenario4: when text exists for relevant tests and lab data exists
            ELSIF l_found_rel_tests = TRUE AND l_found_lab_data_date = TRUE
            THEN
                l_r_reltestsprocedures := l_rel_tests;
            END IF;
        END IF;

        RETURN DBMS_LOB.SUBSTR (l_r_reltestsprocedures, 2000, 1);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN SUBSTR (SQLERRM, 1, 100);
    END F_GET_RESULTSTESTSPROCEDURES;

    --*************************************************************************************************
    --** Name:       F_GET_DRUGINDICATION                                                            **
    --**                                                                                             **
    --** Created by: Surabhi Sharma                                                                  **
    --**                                                                                             **
    --** Creation date: 15/06/2015                                                                   **
    --**                                                                                             **
    --** Purpose:  The Out-of-Box functionality is to create a separate tag for each indication.     **
    --** The change is to map the primary indication in the B.4 structured fields, and               **
    --** insert rest of the indications as text values in B.4.k.19.                                  **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**         PI_SEQ_NUM - 0 for NOTES field, 1 for NOTES_J field                                 **
    --**        PI_IND_ORD - To identify primary or secondary indication                             **
    --**                                                                                             **
    --** Outputs: VARCHAR2(2000), Description with delimited by comma                                **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Surabhi Sharma     15-Jun-2015 CHG0024730  Created                                          **
    --** Sharad Kumar       07-Sep-2016 CHG0024730  Updated for coding standards                     **
    --*************************************************************************************************

    FUNCTION F_GET_DRUGINDICATION (PI_CASE_ID   IN NUMBER,
                                   PI_SEQ_NUM   IN NUMBER,
                                   PI_IND_ORD   IN NUMBER)
        RETURN VARCHAR2
    IS
        l_DRUGINDICATION_LIST   VARCHAR2 (2000) := NULL;
    BEGIN
        IF PI_IND_ORD = 1
        THEN
            SELECT DECODE (esm_utl.get_meddra_version (d.ind_code_dict, 2),
                           NULL, NULL,
                           d.ind_code)
                       DRUGINDICATION
              INTO l_DRUGINDICATION_LIST
              FROM PROD_DOSAGE_INDICATION D
             WHERE     CASE_ID = PI_CASE_ID
                   AND SORT_ID = 1
                   AND SEQ_NUM = PI_SEQ_NUM;
        ELSE
            SELECT SUBSTR (
                       LISTAGG (DRUGINDICATION, ',')
                           WITHIN GROUP (ORDER BY DRUGINDICATION),
                       1,
                       200)
                       DRUGINDICATION
              INTO l_DRUGINDICATION_LIST
              FROM (SELECT DECODE (
                               esm_utl.get_meddra_version (d.ind_code_dict,
                                                           2),
                               NULL, NULL,
                               d.ind_code)
                               DRUGINDICATION
                      FROM PROD_DOSAGE_INDICATION D
                     WHERE     CASE_ID = PI_CASE_ID
                           AND SORT_ID > 1
                           AND SEQ_NUM = PI_SEQ_NUM);
        END IF;

        RETURN l_DRUGINDICATION_LIST;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_DRUGINDICATION;

    --*************************************************************************************************
    --** Name:       F_GET_COMPANYNUMBER_JP                                                          **
    --**                                                                                             **
    --** Created by: Surabhi Sharma                                                                  **
    --**                                                                                             **
    --** Creation date: 15/07/2015                                                                   **
    --**                                                                                             **
    --** Purpose:  The Out-of-Box functionality is to map the field to.                              **
    --** The change is to populate the Additional Info Reference ID where                            **
    --** Additional Info Reference Type is “E2B Company Number-Japan”/“E2B Company Number” if the    **
    --** AUTHORITYNUMB is not populated                                                              **
    --**                                                                                            **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**         PI_AGENCY_ID - It is the Agency to which the report is to be sent                   **
    --**        PI_REPORT_ID -  It is the ID used to reference the report                            **
    --**                                                                                             **
    --** Outputs: VARCHAR2(2000), Description with delimited by comma                                **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Surabhi Sharma     15-Jul-2015  CHG0024730 Created                                          **
    --** Sharad Kumar       07-Sep-2016  CHG0024730 Updated for coding standards
    --** Somesh Thakur      28-NOV-2017  Updated to cater to CW5 migration scenarios
    --*************************************************************************************************

    FUNCTION F_GET_COMPANYNUMBER_JP (PI_CASE_ID       IN NUMBER,
                                     PI_AGENCY_ID     IN NUMBER,
                                     PI_REPORT_ID     IN NUMBER,
                                     PI_PREV_REPORT   IN NUMBER)
        RETURN VARCHAR2
    IS
        l_Initial                  NUMBER := 0;
        l_RetVal                   VARCHAR2 (1000) := NULL;
        l_MigratedCase             NUMBER := 0;
        l_CompanyCaseRefNo         VARCHAR2 (100) := NULL;
        l_CompanyNumber            VARCHAR2 (100) := NULL;
        l_FollowupNum              NUMBER := NULL;
        l_TrackingNum              CMN_REG_REPORTS.TRACKING_NUM%TYPE;
        l_Licenseid                CMN_REG_REPORTS.LICENSE_ID%TYPE;
        l_license_type             LM_LICENSE.LICENSE_TYPE_ID%TYPE;
        l_allow_multiple_reports   NUMBER;
        l_prev_report              CMN_REG_REPORTS.ESM_REPORT_ID%TYPE := NULL;
    BEGIN
        BEGIN
            SELECT CRR.LICENSE_ID,
                   DECODE (CRR.FOLLOWUP_NUM, 0, 0, CRR.FOLLOWUP_NUM),
                   CRR.TRACKING_NUM,
                   CASE
                       WHEN LL.LICENSE_TYPE_ID IN (1, 2, 3) THEN 1
                       ELSE 4
                   END
                       license_type,
                   CASE
                       WHEN LL.LICENSE_TYPE_ID IN (1, 2, 3)
                       THEN
                           LRC.MULT_RPT_INVEST_DRUGS
                       ELSE
                           LRC.MULT_RPT_MKT_DRUGS
                   END
                       allow_multiple_reports
              INTO l_Licenseid,
                   l_FollowupNum,
                   l_TrackingNum,
                   l_license_type,
                   l_allow_multiple_reports
              FROM CMN_REG_REPORTS  CRR
                   JOIN LM_LICENSE LL ON CRR.LICENSE_ID = LL.LICENSE_ID
                   JOIN LM_REGULATORY_CONTACT LRC
                       ON CRR.AGENCY_ID = LRC.AGENCY_ID
             WHERE     CRR.REG_REPORT_ID = PI_REPORT_ID
                   AND CRR.AGENCY_ID = PI_AGENCY_ID
                   AND CRR.DELETED IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_Licenseid := NULL;
                l_FollowupNum := NULL;
                l_TrackingNum := NULL;
        END;

        l_Initial := 0;

        IF l_FollowupNum > 0 AND l_allow_multiple_reports = 1
        THEN
            FOR REC
                IN (  SELECT *
                        FROM CMN_REG_REPORTS
                       WHERE     LICENSE_ID = l_Licenseid
                             AND AGENCY_ID = PI_AGENCY_ID
                             AND TRACKING_NUM = l_TrackingNum
                             AND FOLLOWUP_NUM = l_FollowupNum - 1
                             AND DATE_SUBMITTED IS NOT NULL
                    ORDER BY DATE_GENERATED DESC --AND DATE_SCHEDULED IS NULL --to check if date schedule filter needs to be added?
                                                )
            LOOP
                l_Initial := 1;    -- Applies to all migrated cases Initial/FU
                l_prev_report := rec.esm_report_id;
                EXIT;
            END LOOP;
        ELSIF l_FollowupNum > 0 AND l_allow_multiple_reports = 0
        THEN
            FOR REC
                IN (  SELECT *
                        FROM CMN_REG_REPORTS CRR
                             JOIN LM_LICENSE LL
                                 ON CRR.LICENSE_ID = LL.LICENSE_ID
                       WHERE     (CASE
                                      WHEN LL.LICENSE_TYPE_ID IN (1, 2, 3)
                                      THEN
                                          1
                                      ELSE
                                          4
                                  END) =
                                 l_license_type
                             AND AGENCY_ID = PI_AGENCY_ID
                             AND TRACKING_NUM = l_TrackingNum
                             AND FOLLOWUP_NUM = l_FollowupNum - 1
                             AND DATE_SUBMITTED IS NOT NULL
                    ORDER BY DATE_GENERATED DESC --AND DATE_SCHEDULED IS NULL --to check if date schedule filter needs to be added?
                                                )
            LOOP
                l_Initial := 1;    -- Applies to all migrated cases Initial/FU
                l_prev_report := rec.esm_report_id;
                EXIT;
            END LOOP;
        END IF;

        BEGIN
            SELECT DECODE (
                       (SELECT COUNT (1)
                          FROM case_reference
                         WHERE     case_id = PI_CASE_ID
                               AND ref_type_id IN
                                       (SELECT REF_TYPE_ID
                                          FROM LM_REF_TYPES
                                         WHERE     UPPER (TYPE_DESC) IN
                                                       ('E2B COMPANY NUMBER-JAPAN')
                                               AND DELETED IS NULL)),
                       0, DECODE (
                              (SELECT COUNT (1)
                                 FROM case_reference
                                WHERE     case_id = PI_CASE_ID
                                      AND ref_type_id IN
                                              (SELECT REF_TYPE_ID
                                                 FROM LM_REF_TYPES
                                                WHERE     UPPER (TYPE_DESC) IN
                                                              ('E2B COMPANY NUMBER')
                                                      AND DELETED IS NULL)),
                              0, NULL,
                              (SELECT ref_no
                                 FROM case_reference
                                WHERE     case_id = PI_CASE_ID
                                      AND ref_type_id IN
                                              (SELECT REF_TYPE_ID
                                                 FROM LM_REF_TYPES
                                                WHERE     UPPER (TYPE_DESC) IN
                                                              ('E2B COMPANY NUMBER')
                                                      AND DELETED IS NULL))),
                       (SELECT ref_no
                          FROM case_reference
                         WHERE     case_id = PI_CASE_ID
                               AND ref_type_id IN
                                       (SELECT REF_TYPE_ID
                                          FROM LM_REF_TYPES
                                         WHERE     UPPER (TYPE_DESC) IN
                                                       ('E2B COMPANY NUMBER-JAPAN')
                                               AND DELETED IS NULL))),
                   DECODE (
                       (SELECT COUNT (1)
                          FROM case_reference
                         WHERE     case_id = PI_CASE_ID
                               AND ref_type_id IN
                                       (SELECT REF_TYPE_ID
                                          FROM LM_REF_TYPES
                                         WHERE     UPPER (TYPE_DESC) IN
                                                       ('E2B COMPANY NUMBER-JAPAN')
                                               AND DELETED IS NULL)),
                       0, DECODE (
                              (SELECT COUNT (1)
                                 FROM case_reference
                                WHERE     case_id = PI_CASE_ID
                                      AND ref_type_id IN
                                              (SELECT REF_TYPE_ID
                                                 FROM LM_REF_TYPES
                                                WHERE     UPPER (TYPE_DESC) IN
                                                              ('E2B COMPANY NUMBER')
                                                      AND DELETED IS NULL)),
                              0, 0,
                              1),
                       1)
              INTO l_CompanyCaseRefNo, l_MigratedCase
              FROM CASE_REFERENCE
             WHERE     CASE_ID = PI_CASE_ID
                   AND SORT_ID =
                       (SELECT MIN (SORT_ID)
                          FROM CASE_REFERENCE
                         WHERE     CASE_ID = PI_CASE_ID
                               AND DELETED IS NULL
                               AND REF_TYPE_ID IN
                                       (SELECT REF_TYPE_ID
                                          FROM LM_REF_TYPES
                                         WHERE     UPPER (TYPE_DESC) =
                                                   'E2B COMPANY NUMBER-JAPAN'
                                               AND DELETED IS NULL))
                   AND DELETED IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_CompanyCaseRefNo := NULL;
                l_MigratedCase := NULL;
        END;

        BEGIN
            IF l_MigratedCase = 1
            THEN
                IF l_Initial = 1
                THEN
                    SELECT MIN (companynumb)
                      INTO l_retval
                      FROM safetyreport
                     WHERE report_id = PI_PREV_REPORT;
                --            WHERE report_id = l_prev_report;
                ELSIF l_Initial = 1 AND l_CompanyCaseRefNo IS NOT NULL
                THEN
                    SELECT REF_NO
                      INTO l_RetVal
                      FROM CASE_REFERENCE REF
                     WHERE     CASE_ID = PI_CASE_ID
                           AND DELETED IS NULL
                           AND SORT_ID =
                               (SELECT MIN (SORT_ID)
                                  FROM CASE_REFERENCE
                                 WHERE     CASE_ID = PI_CASE_ID
                                       AND DELETED IS NULL
                                       AND REF_TYPE_ID IN
                                               (SELECT DECODE (
                                                           (SELECT COUNT (1)
                                                              FROM case_reference
                                                             WHERE     case_id =
                                                                       PI_CASE_ID
                                                                   AND ref_type_id IN
                                                                           (SELECT REF_TYPE_ID
                                                                              FROM LM_REF_TYPES
                                                                             WHERE     UPPER (
                                                                                           TYPE_DESC) IN
                                                                                           ('E2B COMPANY NUMBER-JAPAN')
                                                                                   AND DELETED
                                                                                           IS NULL)),
                                                           0, DECODE (
                                                                  (SELECT COUNT (
                                                                              1)
                                                                     FROM case_reference
                                                                    WHERE     case_id =
                                                                              PI_CASE_ID
                                                                          AND ref_type_id IN
                                                                                  (SELECT REF_TYPE_ID
                                                                                     FROM LM_REF_TYPES
                                                                                    WHERE     UPPER (
                                                                                                  TYPE_DESC) IN
                                                                                                  ('E2B COMPANY NUMBER')
                                                                                          AND DELETED
                                                                                                  IS NULL)),
                                                                  NULL, (SELECT REF_TYPE_ID
                                                                           FROM LM_REF_TYPES
                                                                          WHERE     UPPER (
                                                                                        TYPE_DESC) IN
                                                                                        ('E2B COMPANY NUMBER')
                                                                                AND DELETED
                                                                                        IS NULL)),
                                                           (SELECT REF_TYPE_ID
                                                              FROM LM_REF_TYPES
                                                             WHERE     UPPER (
                                                                           TYPE_DESC) IN
                                                                           ('E2B COMPANY NUMBER-JAPAN')
                                                                   AND DELETED
                                                                           IS NULL))
                                                  FROM DUAL))
                           AND NOT EXISTS
                                   (SELECT ref_no authoritynumb
                                      FROM case_reference
                                     WHERE     case_id = PI_CASE_ID
                                           AND DELETED IS NULL
                                           AND (REF_TYPE_ID =
                                                (SELECT REF_TYPE_ID
                                                   FROM LM_REF_TYPES
                                                  WHERE UPPER (TYPE_DESC) =
                                                        'E2B AUTHORITY NUMBER')));
                ELSE
                    -- l_RetVal:= esm_utl.f_get_pmda_e2b_ww_number (PI_CASE_ID,PI_AGENCY_ID,PI_REPORT_ID,'COMPANYNUMB');
                    /* Mofified by Priyanka Arora 10-October-2017*/
                    /* SELECT esm_utl.f_get_pmda_e2b_ww_number (PI_CASE_ID,PI_AGENCY_ID,PI_REPORT_ID,'SAFETYREPORTID')
                    INTO l_RetVal
                    FROM DUAL
                    WHERE NOT EXISTS
                    (SELECT ref_no authoritynumb
                    FROM case_reference
                    WHERE case_id     = PI_CASE_ID
                    AND ( REF_TYPE_ID =
                    (SELECT REF_TYPE_ID
                    FROM LM_REF_TYPES
                    WHERE UPPER ( TYPE_DESC) = 'E2B AUTHORITY NUMBER'
                    ))
                    );*/
                    SELECT DECODE (
                               (SELECT COUNT (1)
                                  FROM case_reference
                                 WHERE     case_id = PI_CASE_ID
                                       AND ref_type_id IN
                                               (SELECT REF_TYPE_ID
                                                  FROM LM_REF_TYPES
                                                 WHERE     UPPER (TYPE_DESC) IN
                                                               ('E2B COMPANY NUMBER-JAPAN')
                                                       AND DELETED IS NULL)), --company number
                               0, --esm_utl.f_get_pmda_e2b_ww_number (PI_CASE_ID,PI_AGENCY_ID,PI_REPORT_ID,'COMPANYNUMB'),
                                  DECODE (
                                      (SELECT COUNT (1)
                                         FROM case_reference
                                        WHERE     case_id = PI_CASE_ID
                                              AND ref_type_id IN
                                                      (SELECT REF_TYPE_ID
                                                         FROM LM_REF_TYPES
                                                        WHERE     UPPER (
                                                                      TYPE_DESC) IN
                                                                      ('E2B COMPANY NUMBER')
                                                              AND DELETED
                                                                      IS NULL)),
                                      0, esm_utl.f_get_pmda_e2b_ww_number (
                                             PI_CASE_ID,
                                             PI_AGENCY_ID,
                                             PI_REPORT_ID,
                                             'SAFETYREPORTID'),
                                      (SELECT (SELECT ref_no
                                                 FROM case_reference
                                                WHERE     case_id =
                                                          PI_CASE_ID
                                                      AND ref_type_id IN
                                                              (SELECT REF_TYPE_ID
                                                                 FROM LM_REF_TYPES
                                                                WHERE     UPPER (
                                                                              TYPE_DESC) IN
                                                                              ('E2B COMPANY NUMBER')
                                                                      AND DELETED
                                                                              IS NULL)
                                                      AND SEQ_NUM =
                                                          (SELECT MIN (
                                                                      SEQ_NUM)
                                                             FROM CASE_REFERENCE
                                                            WHERE     CASE_ID =
                                                                      PI_CASE_ID
                                                                  AND REF_TYPE_ID IN
                                                                          (SELECT REF_TYPE_ID
                                                                             FROM LM_REF_TYPES
                                                                            WHERE     UPPER (
                                                                                          TYPE_DESC) IN
                                                                                          ('E2B COMPANY NUMBER')
                                                                                  AND DELETED
                                                                                          IS NULL)))
                                                  companynumb
                                         FROM DUAL
                                        WHERE NOT EXISTS
                                                  (SELECT ref_no
                                                              authoritynumb
                                                     FROM case_reference
                                                    WHERE     case_id =
                                                              PI_CASE_ID
                                                          AND (REF_TYPE_ID =
                                                               (SELECT REF_TYPE_ID
                                                                  FROM LM_REF_TYPES
                                                                 WHERE UPPER (
                                                                           TYPE_DESC) =
                                                                       'E2B AUTHORITY NUMBER'))))),
                               (SELECT (SELECT ref_no
                                          FROM case_reference
                                         WHERE     case_id = PI_CASE_ID
                                               AND ref_type_id IN
                                                       (SELECT REF_TYPE_ID
                                                          FROM LM_REF_TYPES
                                                         WHERE     UPPER (
                                                                       TYPE_DESC) IN
                                                                       ('E2B COMPANY NUMBER-JAPAN')
                                                               AND DELETED
                                                                       IS NULL)
                                               AND SEQ_NUM =
                                                   (SELECT MIN (SEQ_NUM)
                                                      FROM CASE_REFERENCE
                                                     WHERE     CASE_ID =
                                                               PI_CASE_ID
                                                           AND REF_TYPE_ID IN
                                                                   (SELECT REF_TYPE_ID
                                                                      FROM LM_REF_TYPES
                                                                     WHERE     UPPER (
                                                                                   TYPE_DESC) IN
                                                                                   ('E2B COMPANY NUMBER-JAPAN')
                                                                           AND DELETED
                                                                                   IS NULL)))
                                           companynumb
                                  FROM DUAL
                                 WHERE NOT EXISTS
                                           (SELECT ref_no authoritynumb
                                              FROM case_reference
                                             WHERE     case_id = PI_CASE_ID
                                                   AND (REF_TYPE_ID =
                                                        (SELECT REF_TYPE_ID
                                                           FROM LM_REF_TYPES
                                                          WHERE UPPER (
                                                                    TYPE_DESC) =
                                                                'E2B AUTHORITY NUMBER')))))
                      INTO l_RetVal
                      FROM DUAL;
                END IF;
            ELSE
                SELECT DECODE (
                           (SELECT COUNT (1)
                              FROM case_reference
                             WHERE     case_id = PI_CASE_ID
                                   AND ref_type_id IN
                                           (SELECT REF_TYPE_ID
                                              FROM LM_REF_TYPES
                                             WHERE     UPPER (TYPE_DESC) IN
                                                           ('E2B COMPANY NUMBER-JAPAN')
                                                   AND DELETED IS NULL)), --company number
                           0, --esm_utl.f_get_pmda_e2b_ww_number (PI_CASE_ID,PI_AGENCY_ID,PI_REPORT_ID,'COMPANYNUMB'),
                              DECODE (
                                  (SELECT COUNT (1)
                                     FROM case_reference
                                    WHERE     case_id = PI_CASE_ID
                                          AND ref_type_id IN
                                                  (SELECT REF_TYPE_ID
                                                     FROM LM_REF_TYPES
                                                    WHERE     UPPER (
                                                                  TYPE_DESC) IN
                                                                  ('E2B COMPANY NUMBER')
                                                          AND DELETED IS NULL)),
                                  0, esm_utl.f_get_pmda_e2b_ww_number (
                                         PI_CASE_ID,
                                         PI_AGENCY_ID,
                                         PI_REPORT_ID,
                                         'SAFETYREPORTID'),
                                  (SELECT (SELECT ref_no
                                             FROM case_reference
                                            WHERE     case_id = PI_CASE_ID
                                                  AND ref_type_id IN
                                                          (SELECT REF_TYPE_ID
                                                             FROM LM_REF_TYPES
                                                            WHERE     UPPER (
                                                                          TYPE_DESC) IN
                                                                          ('E2B COMPANY NUMBER')
                                                                  AND DELETED
                                                                          IS NULL)
                                                  AND SEQ_NUM =
                                                      (SELECT MIN (SEQ_NUM)
                                                         FROM CASE_REFERENCE
                                                        WHERE     CASE_ID =
                                                                  PI_CASE_ID
                                                              AND REF_TYPE_ID IN
                                                                      (SELECT REF_TYPE_ID
                                                                         FROM LM_REF_TYPES
                                                                        WHERE     UPPER (
                                                                                      TYPE_DESC) IN
                                                                                      ('E2B COMPANY NUMBER')
                                                                              AND DELETED
                                                                                      IS NULL)))
                                              companynumb
                                     FROM DUAL
                                    WHERE NOT EXISTS
                                              (SELECT ref_no authoritynumb
                                                 FROM case_reference
                                                WHERE     case_id =
                                                          PI_CASE_ID
                                                      AND (REF_TYPE_ID =
                                                           (SELECT REF_TYPE_ID
                                                              FROM LM_REF_TYPES
                                                             WHERE UPPER (
                                                                       TYPE_DESC) =
                                                                   'E2B AUTHORITY NUMBER'))))),
                           (SELECT (SELECT ref_no
                                      FROM case_reference
                                     WHERE     case_id = PI_CASE_ID
                                           AND ref_type_id IN
                                                   (SELECT REF_TYPE_ID
                                                      FROM LM_REF_TYPES
                                                     WHERE     UPPER (
                                                                   TYPE_DESC) IN
                                                                   ('E2B COMPANY NUMBER-JAPAN')
                                                           AND DELETED
                                                                   IS NULL)
                                           AND SEQ_NUM =
                                               (SELECT MIN (SEQ_NUM)
                                                  FROM CASE_REFERENCE
                                                 WHERE     CASE_ID =
                                                           PI_CASE_ID
                                                       AND REF_TYPE_ID IN
                                                               (SELECT REF_TYPE_ID
                                                                  FROM LM_REF_TYPES
                                                                 WHERE     UPPER (
                                                                               TYPE_DESC) IN
                                                                               ('E2B COMPANY NUMBER-JAPAN')
                                                                       AND DELETED
                                                                               IS NULL)))
                                       companynumb
                              FROM DUAL
                             WHERE NOT EXISTS
                                       (SELECT ref_no authoritynumb
                                          FROM case_reference
                                         WHERE     case_id = PI_CASE_ID
                                               AND (REF_TYPE_ID =
                                                    (SELECT REF_TYPE_ID
                                                       FROM LM_REF_TYPES
                                                      WHERE UPPER (TYPE_DESC) =
                                                            'E2B AUTHORITY NUMBER')))))
                  INTO l_RetVal
                  FROM DUAL;
            END IF;
        END;

        RETURN l_RetVal;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_COMPANYNUMBER_JP;

    --*************************************************************************************************
    --** Name:       F_GET_DRUGAUTHORIZATIONNUMB                                                     **
    --**                                                                                             **
    --** Created by: Surabhi Sharma                                                                  **
    --**                                                                                             **
    --** Creation date: 15/12/2015                                                                   **
    --**                                                                                             **
    --** Purpose:The Out-of-Box functionality is to populate the field for primary suspect products  **
    --** The change is to populate the DRUGAUTHORIZATIONNUMB for non-primary suspect products        **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**         PI_SEQ_NUM - It is the Product sequence for which the report is to be sent          **
    --**        PI_REG_REPORT_ID -  It is the ID used to reference the report                        **
    --**                                                                                             **
    --** Outputs: VARCHAR2(2000), Description with delimited by comma                                **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Surabhi Sharma     15-Dec-2015  CHG0024730  Created                                         **
    --** Sharad Kumar       07-Sep-2016  CHG0024730  Updated for coding standards                    **
    --*************************************************************************************************

    FUNCTION F_GET_DRUGAUTHORIZATIONNUMB (PI_CASE_ID         IN NUMBER,
                                          PI_SEQ_NUM         IN NUMBER,
                                          PI_REG_REPORT_ID   IN NUMBER)
        RETURN VARCHAR2
    IS
        l_DRUGAUTHORIZATIONNUMB   VARCHAR2 (2000);
    BEGIN
        SELECT DECODE (
                   SUBSTR (
                       SUBSTR (
                           esm_owner.ESM_UTL_B4k4.F_Lic (PI_CASE_ID,
                                                         PI_SEQ_NUM,
                                                         PI_REG_REPORT_ID),
                           1,
                           35),
                       1,
                       3),
                   'MKT', NULL,
                   'CTA', NULL,
                   SUBSTR (
                       esm_owner.ESM_UTL_B4k4.F_Lic (PI_CASE_ID,
                                                     PI_SEQ_NUM,
                                                     PI_REG_REPORT_ID),
                       1,
                       35))
                   drugauthorizationnumb
          INTO l_DRUGAUTHORIZATIONNUMB
          FROM DUAL;

        RETURN l_DRUGAUTHORIZATIONNUMB;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_DRUGAUTHORIZATIONNUMB;

    --*************************************************************************************************
    --** Name:       F_GET_MEDICINAL_SECONDARY_PROD                                                  **
    --**                                                                                             **
    --** Created by: Sharad Kumar                                                                    **
    --**                                                                                             **
    --** Creation date: 20/10/2016                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic for medicinalproduct dtd_element to populate J DRUG CODE/Trade Name J  **
    --**        for secondary products                                                               **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**         PI_PROD_SEQ_NUM - It is the Product sequence for which the report is to be sent     **
    --**        PI_REG_REPORT_ID -  It is the ID used to reference the report                        **
    --**                                                                                             **
    --** Outputs: VARCHAR2: Return the J DRUG CODE or Trade Name J                                   **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Sharad Kumar       20-OCT-2016  CHG0024730  Created                                         **
    --** Sharad Kumar       15-NOV-2016  CHG0024730  Logic for exclude from report check box         **
    --**                                             and award date selection                        **
    --*************************************************************************************************

    FUNCTION F_GET_MEDICINAL_SECONDARY_PROD (PI_CASE_ID         IN NUMBER,
                                             PI_PROD_SEQ_NUM    IN NUMBER,
                                             PI_REG_REPORT_ID   IN NUMBER)
        RETURN VARCHAR2
    IS
        /*Variables*/
        lv_case_id         argus_app.case_master.case_id%TYPE := 0;
        /*case id from the report*/
        lv_prod_seq_num    argus_app.case_product.seq_num%TYPE := 0;
        /*product sequence number from the report*/
        lv_reg_report_id   argus_app.cmn_reg_reports.reg_report_id%TYPE := 0;
        /*reg_report id from the report*/
        lv_loop_cntr       NUMBER (10) := 0;
        /*Loop counter to check if cursor has values for the given parameters*/
        lv_return          VARCHAR2 (1000 CHAR) := NULL;

        /*Cursors*/
        /*Get the license and license type from the report for the primary product*/
        CURSOR c_get_rep_lic (
            p_case_id          NUMBER,
            p_reg_report_id    NUMBER)
        IS
            SELECT cmrr.license_id, ll.license_type_id
              FROM cmn_reg_reports  cmrr
                   JOIN case_reg_reports crr
                       ON (crr.reg_report_id = cmrr.reg_report_id)
                   JOIN lm_license ll ON (ll.license_id = cmrr.license_id)
             WHERE     crr.case_id = p_case_id
                   AND cmrr.reg_report_id = p_reg_report_id;

        /*Get the marketed japan license from assessment*/
        CURSOR c_get_asses_mkt_lic (
            p_case_id         NUMBER,
            p_prod_seq_num    NUMBER)
        IS
            SELECT license_id
              FROM (SELECT cea.license_id,
                           DENSE_RANK ()
                           OVER (PARTITION BY cea.case_id
                                 ORDER BY ll.award_date ASC, llp.seq_num ASC)
                               rnk
                      FROM case_event_assess  cea
                           JOIN lm_license ll
                               ON (ll.license_id = cea.license_id)
                           JOIN lm_datasheet ld
                               ON (ld.datasheet_id = cea.datasheet_id)
                           JOIN case_product cp
                               ON (    cp.case_id = cea.case_id
                                   AND cp.seq_num = cea.prod_seq_num)
                           JOIN lm_product lp
                               ON (lp.product_id =
                                   NVL (cp.product_id, cp.pat_exposure))
                           JOIN lm_lic_products llp
                               ON (    llp.product_id = lp.product_id
                                   AND llp.license_id = ll.license_id)
                     WHERE     cea.case_id = p_case_id
                           AND cea.prod_seq_num = p_prod_seq_num
                           AND cp.case_id = p_case_id
                           AND cp.seq_num = p_prod_seq_num
                           AND ll.license_type_id IN (4, 5, 6)
                           AND ll.country_id = 107
                           AND ld.sheet_name = 'JP'
                           AND ll.exclude_rpt_candidate = 0)
             WHERE rnk = 1;

        /*Get the investigational japan license from assessment*/
        CURSOR c_get_asses_inv_lic (
            p_case_id         NUMBER,
            p_prod_seq_num    NUMBER)
        IS
            SELECT license_id, trade_name_j
              FROM (SELECT cea.license_id,
                           ll.trade_name_j,
                           DENSE_RANK ()
                           OVER (PARTITION BY cea.case_id
                                 ORDER BY ll.award_date ASC, llp.seq_num ASC)
                               rnk
                      FROM case_event_assess  cea
                           JOIN lm_license ll
                               ON (ll.license_id = cea.license_id)
                           JOIN lm_datasheet ld
                               ON (ld.datasheet_id = cea.datasheet_id)
                           JOIN case_product cp
                               ON (    cp.case_id = cea.case_id
                                   AND cp.seq_num = cea.prod_seq_num)
                           JOIN lm_product lp
                               ON (lp.product_id =
                                   NVL (cp.product_id, cp.pat_exposure))
                           JOIN lm_lic_products llp
                               ON (    llp.product_id = lp.product_id
                                   AND llp.license_id = ll.license_id)
                     WHERE     cea.case_id = p_case_id
                           AND cea.prod_seq_num = p_prod_seq_num
                           AND cp.case_id = p_case_id
                           AND cp.seq_num = p_prod_seq_num
                           AND ll.license_type_id IN (1, 2, 3)
                           AND ll.country_id = 107
                           AND ld.sheet_name = 'JP - IB'
                           AND ll.exclude_rpt_candidate = 0)
             WHERE rnk = 1;

        /*Get the connected product id*/
        CURSOR c_get_conn_prod (p_license_id NUMBER)
        IS
            SELECT license_id, product_id
              FROM lm_lic_products llp
             WHERE     license_id = p_license_id
                   AND seq_num = (SELECT MIN (seq_num)
                                    FROM lm_lic_products llpi
                                   WHERE llpi.license_id = llp.license_id);

        /*Get product_id or pat_exposure to handle the scenario where only license where exclude from report is checked*/
        CURSOR c_get_study_prod (p_case_id NUMBER, p_prod_seq_num NUMBER)
        IS
            SELECT product_id, pat_exposure
              FROM case_product
             WHERE case_id = lv_case_id AND seq_num = lv_prod_seq_num;
    BEGIN
        /*Initializing local variables*/
        lv_loop_cntr := 0;
        /*Initialize to 0*/
        lv_case_id := pi_case_id;
        lv_prod_seq_num := pi_prod_seq_num;
        lv_reg_report_id := pi_reg_report_id;

        FOR get_pri_lic_type IN c_get_rep_lic (lv_case_id, lv_reg_report_id)
        LOOP
            lv_loop_cntr := lv_loop_cntr + 1;

            /*Cursor has data*/
            IF get_pri_lic_type.license_type_id IN (4, 5, 6)
            THEN
                /*Primary product in the report has marketed license*/
                lv_loop_cntr := 0;

                /*Get the marketed license for the secondary product*/
                FOR get_mkt_lic
                    IN c_get_asses_mkt_lic (lv_case_id, lv_prod_seq_num)
                LOOP
                    /*Get the connected product id*/
                    FOR get_conn_prod
                        IN c_get_conn_prod (get_mkt_lic.license_id)
                    LOOP
                        lv_loop_cntr := lv_loop_cntr + 1;

                        /*Cursor has data*/
                        /*Get the J drug code*/
                        BEGIN
                            SELECT lp.drl_id_j
                              INTO lv_return
                              FROM lm_product lp
                             WHERE lp.product_id = get_conn_prod.product_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_return := NULL;
                        END;

                        /*If the J drug code does not exists then return the trade name j*/
                        IF lv_return IS NULL
                        THEN
                            BEGIN
                                SELECT trade_name_j
                                  INTO lv_return
                                  FROM lm_license
                                 WHERE license_id = get_mkt_lic.license_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_return := NULL;
                            END;
                        END IF;
                    END LOOP;
                END LOOP;

                /*If no marketed details are found then check for investigational*/
                IF ((lv_loop_cntr = 0) OR (lv_return IS NULL))
                THEN
                    lv_loop_cntr := 0;

                    /*Get the investigational license for the secondary product*/
                    FOR get_inv_lic
                        IN c_get_asses_inv_lic (lv_case_id, lv_prod_seq_num)
                    LOOP
                        /*Get the trade name J*/
                        lv_loop_cntr := lv_loop_cntr + 1;

                        IF get_inv_lic.trade_name_j IS NOT NULL
                        THEN
                            lv_return := get_inv_lic.trade_name_j;
                        ELSE
                            lv_return := NULL;
                        END IF;
                    END LOOP;
                END IF;
            ELSIF get_pri_lic_type.license_type_id IN (1, 2, 3)
            THEN
                /*Primary product in the report has investigational license*/
                lv_loop_cntr := 0;

                /*Get the investigational license for the secondary product*/
                FOR get_inv_lic
                    IN c_get_asses_inv_lic (lv_case_id, lv_prod_seq_num)
                LOOP
                    /*Get the trade name J*/
                    lv_loop_cntr := lv_loop_cntr + 1;

                    IF get_inv_lic.trade_name_j IS NOT NULL
                    THEN
                        lv_return := get_inv_lic.trade_name_j;
                    ELSE
                        lv_return := NULL;
                    END IF;
                END LOOP;

                /*If investigational license is not found or trade name J is not present for the investigational license*/
                IF ((lv_loop_cntr = 0) OR (lv_return IS NULL))
                THEN
                    lv_loop_cntr := 0;

                    /*Get the marketed license for the secondary product*/
                    FOR get_mkt_lic
                        IN c_get_asses_mkt_lic (lv_case_id, lv_prod_seq_num)
                    LOOP
                        /*Get the connected product id*/
                        FOR get_conn_prod
                            IN c_get_conn_prod (get_mkt_lic.license_id)
                        LOOP
                            lv_loop_cntr := lv_loop_cntr + 1;

                            /*Cursor has data*/
                            /*Get the J drug code*/
                            BEGIN
                                SELECT lp.drl_id_j
                                  INTO lv_return
                                  FROM lm_product lp
                                 WHERE lp.product_id =
                                       get_conn_prod.product_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_return := NULL;
                            END;

                            /*If the J drug code does not exists then return the trade name j*/
                            IF lv_return IS NULL
                            THEN
                                BEGIN
                                    SELECT trade_name_j
                                      INTO lv_return
                                      FROM lm_license
                                     WHERE license_id =
                                           get_mkt_lic.license_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_return := NULL;
                                END;
                            END IF;
                        END LOOP;
                    END LOOP;
                END IF;
            ELSE
                /*Primary product in the report does not have valid license type*/
                lv_loop_cntr := 0;
            END IF;
        END LOOP;

        /*when only license where exclude from report is checked*/
        IF lv_return IS NULL OR lv_loop_cntr = 0
        THEN
            FOR get_study_prod
                IN c_get_study_prod (lv_case_id, lv_prod_seq_num)
            LOOP
                /*check for non study product and return prod_name_j from case form*/
                IF     get_study_prod.product_id IS NOT NULL
                   AND get_study_prod.product_id <> 0
                THEN
                    SELECT NVL (product_name_j, product_name)
                      INTO lv_return
                      FROM case_product
                     WHERE seq_num = lv_prod_seq_num AND case_id = lv_case_id;
                ELSE
                    /*check for study product and return prod_name_j from configuration*/
                    SELECT NVL (prod_name_j, prod_name)
                      INTO lv_return
                      FROM lm_product
                     WHERE product_id = NVL (get_study_prod.pat_exposure, 0);
                END IF;
            END LOOP;
        END IF;

        RETURN lv_return;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            /*In case of NO_DATA_FOUND exception return null*/
            RETURN NULL;
        WHEN OTHERS
        THEN
            /*In case of any unhandeled exception return null*/
            RETURN NULL;
    END F_GET_MEDICINAL_SECONDARY_PROD;

    --*************************************************************************************************
    --** Name:       F_GET_ACTIVESUB_SECONDARY_PROD                                                  **
    --**                                                                                             **
    --** Created by: Sharad Kumar                                                                    **
    --**                                                                                             **
    --** Creation date: 20/10/2016                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic for activesubtance dtd_element to populate CCN/Prod Generic Name J     **
    --**        for secondary products                                                               **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**         PI_PROD_SEQ_NUM - It is the Product sequence for which the report is to be sent     **
    --**         PI_PROD_ID - It is the Product ID for which the report is to be sent                **
    --**        PI_REG_REPORT_ID -  It is the ID used to reference the report                        **
    --**                                                                                             **
    --** Outputs: VARCHAR2: Return the CCN OR Prod Generic Name J                                    **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Sharad Kumar       20-OCT-2016  CHG0024730  Created                                         **
    --** Sharad Kumar       15-NOV-2016  CHG0024730  Logic for exclude from report check box         **
    --**                                             and award date selection                        **
    --*************************************************************************************************

    FUNCTION F_GET_ACTIVESUB_SECONDARY_PROD (PI_CASE_ID         IN NUMBER,
                                             PI_PROD_SEQ_NUM    IN NUMBER,
                                             PI_PROD_ID         IN NUMBER,
                                             PI_REG_REPORT_ID   IN NUMBER)
        RETURN VARCHAR2
    IS
        /*Variables*/
        lv_case_id         argus_app.case_master.case_id%TYPE := 0;
        /*case id from the report*/
        lv_prod_seq_num    argus_app.case_product.seq_num%TYPE := 0;
        /*product sequence number from the report*/
        lv_prod_id         argus_app.case_product.product_id%TYPE := 0;
        /*product id from the report*/
        lv_reg_report_id   argus_app.cmn_reg_reports.reg_report_id%TYPE := 0;
        /*reg_report id from the report*/
        lv_loop_cntr       NUMBER (10) := 0;
        /*Loop counter to check if cursor has values for the given parameters*/
        lv_return          VARCHAR2 (1000 CHAR) := NULL;

        /*Cursors*/
        /*Get the license and license type from the report for the primary product*/
        CURSOR c_get_rep_lic (
            p_case_id          NUMBER,
            p_reg_report_id    NUMBER)
        IS
            SELECT cmrr.license_id, ll.license_type_id
              FROM cmn_reg_reports  cmrr
                   JOIN case_reg_reports crr
                       ON (crr.reg_report_id = cmrr.reg_report_id)
                   JOIN lm_license ll ON (ll.license_id = cmrr.license_id)
             WHERE     crr.case_id = p_case_id
                   AND cmrr.reg_report_id = p_reg_report_id;

        /*Get the marketed japan license from assessment*/
        CURSOR c_get_asses_mkt_lic (
            p_case_id         NUMBER,
            p_prod_seq_num    NUMBER)
        IS
            SELECT license_id
              FROM (SELECT cea.license_id,
                           DENSE_RANK ()
                           OVER (PARTITION BY cea.case_id
                                 ORDER BY ll.award_date ASC, llp.seq_num ASC)
                               rnk
                      FROM case_event_assess  cea
                           JOIN lm_license ll
                               ON (ll.license_id = cea.license_id)
                           JOIN lm_datasheet ld
                               ON (ld.datasheet_id = cea.datasheet_id)
                           JOIN case_product cp
                               ON (    cp.case_id = cea.case_id
                                   AND cp.seq_num = cea.prod_seq_num)
                           JOIN lm_product lp
                               ON (lp.product_id =
                                   NVL (cp.product_id, cp.pat_exposure))
                           JOIN lm_lic_products llp
                               ON (    llp.product_id = lp.product_id
                                   AND llp.license_id = ll.license_id)
                     WHERE     cea.case_id = p_case_id
                           AND cea.prod_seq_num = p_prod_seq_num
                           AND cp.case_id = p_case_id
                           AND cp.seq_num = p_prod_seq_num
                           AND ll.license_type_id IN (4, 5, 6)
                           AND ll.country_id = 107
                           AND ld.sheet_name = 'JP'
                           AND ll.exclude_rpt_candidate = 0)
             WHERE rnk = 1;

        /*Get the investigational japan license from assessment*/
        CURSOR c_get_asses_inv_lic (
            p_case_id         NUMBER,
            p_prod_seq_num    NUMBER)
        IS
            SELECT license_id, trade_name_j
              FROM (SELECT cea.license_id,
                           ll.trade_name_j,
                           DENSE_RANK ()
                           OVER (PARTITION BY cea.case_id
                                 ORDER BY ll.award_date ASC, llp.seq_num ASC)
                               rnk
                      FROM case_event_assess  cea
                           JOIN lm_license ll
                               ON (ll.license_id = cea.license_id)
                           JOIN lm_datasheet ld
                               ON (ld.datasheet_id = cea.datasheet_id)
                           JOIN case_product cp
                               ON (    cp.case_id = cea.case_id
                                   AND cp.seq_num = cea.prod_seq_num)
                           JOIN lm_product lp
                               ON (lp.product_id =
                                   NVL (cp.product_id, cp.pat_exposure))
                           JOIN lm_lic_products llp
                               ON (    llp.product_id = lp.product_id
                                   AND llp.license_id = ll.license_id)
                     WHERE     cea.case_id = p_case_id
                           AND cea.prod_seq_num = p_prod_seq_num
                           AND cp.case_id = p_case_id
                           AND cp.seq_num = p_prod_seq_num
                           AND ll.license_type_id IN (1, 2, 3)
                           AND ll.country_id = 107
                           AND ld.sheet_name = 'JP - IB'
                           AND ll.exclude_rpt_candidate = 0)
             WHERE rnk = 1;

        /*Get the connected product id*/
        CURSOR c_get_conn_prod (p_license_id NUMBER)
        IS
            SELECT license_id, product_id
              FROM lm_lic_products llp
             WHERE     license_id = p_license_id
                   AND seq_num = (SELECT MIN (seq_num)
                                    FROM lm_lic_products llpi
                                   WHERE llpi.license_id = llp.license_id);

        /*Get product_id or pat_exposure to handle the scenario where only license where exclude from report is checked*/
        CURSOR c_get_study_prod (p_case_id NUMBER, p_prod_seq_num NUMBER)
        IS
            SELECT product_id, pat_exposure
              FROM case_product
             WHERE case_id = lv_case_id AND seq_num = lv_prod_seq_num;
    BEGIN
        /*Initializing local variables*/
        lv_loop_cntr := 0;
        /*Initialize to 0*/
        lv_case_id := pi_case_id;
        lv_prod_seq_num := pi_prod_seq_num;
        lv_reg_report_id := pi_reg_report_id;
        lv_prod_id := pi_prod_id;

        FOR get_pri_lic_type IN c_get_rep_lic (lv_case_id, lv_reg_report_id)
        LOOP
            lv_loop_cntr := lv_loop_cntr + 1;

            /*Cursor has data*/
            IF get_pri_lic_type.license_type_id IN (4, 5, 6)
            THEN
                /*Primary product in the report has marketed license*/
                lv_loop_cntr := 0;

                /*Get the marketed license for the secondary product*/
                FOR get_mkt_lic
                    IN c_get_asses_mkt_lic (lv_case_id, lv_prod_seq_num)
                LOOP
                    /*Get the connected product id*/
                    FOR get_conn_prod
                        IN c_get_conn_prod (get_mkt_lic.license_id)
                    LOOP
                        lv_loop_cntr := lv_loop_cntr + 1;

                        /*Cursor has data*/
                        /*Get the J drug code*/
                        BEGIN
                            SELECT CASE
                                       WHEN NVL (lp.drug_code_type_j, 1) = 1
                                       THEN
                                           SUBSTR (lp.drl_id_j, 1, 7)
                                       ELSE
                                           lp.drl_id_j
                                   END
                                       j_drug_code
                              INTO lv_return
                              FROM lm_product lp
                             WHERE lp.product_id = get_conn_prod.product_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_return := NULL;
                        END;

                        /*If the J drug code does not exists then return the ccn or product generic name J*/
                        IF lv_return IS NULL
                        THEN
                            BEGIN
                                SELECT DBMS_LOB.SUBSTR (
                                           lpi.prod_generic_name_j,
                                           1000,
                                           1)
                                           ccn_gen_name_j
                                  INTO lv_return
                                  FROM lm_product lpi
                                 WHERE lpi.product_id = lv_prod_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_return := NULL;
                            END;
                        END IF;
                    END LOOP;
                END LOOP;

                /*If no marketed details are found then check for investigational*/
                IF ((lv_loop_cntr = 0) OR (lv_return IS NULL))
                THEN
                    /*Get the investigational license for the secondary product*/
                    FOR get_inv_lic
                        IN c_get_asses_inv_lic (lv_case_id, lv_prod_seq_num)
                    LOOP
                        /*Get the trade name J*/
                        lv_loop_cntr := lv_loop_cntr + 1;

                        /*Get ccn or generic name J for the secondary product*/
                        BEGIN
                            SELECT NVL (
                                       lspc.ccn,
                                       DBMS_LOB.SUBSTR (
                                           lpi.prod_generic_name_j,
                                           1000,
                                           1))
                              INTO lv_return
                              FROM lm_product                    lpi,
                                   case_study                    cs,
                                   argus_app.lss_study_prod_ccn  lspc
                             WHERE     cs.case_id = lv_case_id
                                   AND lpi.product_id = lv_prod_id
                                   AND lspc.study_key(+) = cs.study_key
                                   AND lspc.deleted IS NULL
                                   AND lspc.product_id(+) = lv_prod_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_loop_cntr := 0;
                                lv_return := NULL;
                        END;
                    END LOOP;
                END IF;
            ELSIF get_pri_lic_type.license_type_id IN (1, 2, 3)
            THEN
                /*Primary product in the report has investigational license*/
                lv_loop_cntr := 0;

                /*Get the investigational license for the secondary product*/
                FOR get_inv_lic
                    IN c_get_asses_inv_lic (lv_case_id, lv_prod_seq_num)
                LOOP
                    /*Get the trade name J*/
                    lv_loop_cntr := lv_loop_cntr + 1;

                    BEGIN
                        SELECT NVL (
                                   lspc.ccn,
                                   DBMS_LOB.SUBSTR (lpi.prod_generic_name_j,
                                                    1000,
                                                    1))
                          INTO lv_return
                          FROM lm_product                    lpi,
                               case_study                    cs,
                               argus_app.lss_study_prod_ccn  lspc
                         WHERE     cs.case_id = lv_case_id
                               AND lpi.product_id = lv_prod_id
                               AND lspc.study_key(+) = cs.study_key
                               AND lspc.deleted IS NULL
                               AND lspc.product_id(+) = lv_prod_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_loop_cntr := 0;
                            lv_return := NULL;
                    END;
                END LOOP;

                /*If investigational license is not found or trade name J is not present for the investigational license*/
                IF ((lv_loop_cntr = 0) OR (lv_return IS NULL))
                THEN
                    lv_loop_cntr := 0;

                    /*Get the marketed license for the secondary product*/
                    FOR get_mkt_lic
                        IN c_get_asses_mkt_lic (lv_case_id, lv_prod_seq_num)
                    LOOP
                        /*Get the connected product id*/
                        FOR get_conn_prod
                            IN c_get_conn_prod (get_mkt_lic.license_id)
                        LOOP
                            lv_loop_cntr := lv_loop_cntr + 1;

                            /*Cursor has data*/
                            /*Get the J drug code*/
                            BEGIN
                                SELECT CASE
                                           WHEN NVL (lp.drug_code_type_j, 1) =
                                                1
                                           THEN
                                               SUBSTR (lp.drl_id_j, 1, 7)
                                           ELSE
                                               lp.drl_id_j
                                       END
                                           j_drug_code
                                  INTO lv_return
                                  FROM lm_product lp
                                 WHERE lp.product_id =
                                       get_conn_prod.product_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_return := NULL;
                            END;

                            /*If the J drug code does not exists then return the trade name j*/
                            IF lv_return IS NULL
                            THEN
                                BEGIN
                                    SELECT DBMS_LOB.SUBSTR (
                                               lpi.prod_generic_name_j,
                                               1000,
                                               1)
                                               ccn_gen_name_j
                                      INTO lv_return
                                      FROM lm_product lpi
                                     WHERE lpi.product_id = lv_prod_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_return := NULL;
                                END;
                            END IF;
                        END LOOP;
                    END LOOP;
                END IF;
            ELSE
                /*Primary product in the report does not have valid license type*/
                lv_loop_cntr := 0;
            END IF;
        END LOOP;

        /*when only license where exclude from report is checked*/
        IF lv_return IS NULL OR lv_loop_cntr = 0
        THEN
            FOR get_study_prod
                IN c_get_study_prod (lv_case_id, lv_prod_seq_num)
            LOOP
                /*check for non study product and return prod_name_j from case form*/
                IF     get_study_prod.product_id IS NOT NULL
                   AND get_study_prod.product_id <> 0
                THEN
                    SELECT DBMS_LOB.SUBSTR (prod_generic_name_j, 1000, 1)
                      INTO lv_return
                      FROM lm_product
                     WHERE product_id =
                           (SELECT product_id
                              FROM case_product
                             WHERE     case_id = lv_case_id
                                   AND seq_num = lv_prod_seq_num);
                ELSE
                    /*check for study product and return prod_name_j from configuration*/
                    SELECT DBMS_LOB.SUBSTR (prod_generic_name_j, 1000, 1)
                      INTO lv_return
                      FROM lm_product
                     WHERE product_id =
                           (SELECT pat_exposure
                              FROM case_product
                             WHERE     case_id = lv_case_id
                                   AND seq_num = lv_prod_seq_num);
                END IF;
            END LOOP;
        END IF;

        RETURN lv_return;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            /*In case of NO_DATA_FOUND exception return null*/
            RETURN NULL;
        WHEN OTHERS
        THEN
            /*In case of any unhandeled exception return null*/
            RETURN NULL;
    END F_GET_ACTIVESUB_SECONDARY_PROD;

    FUNCTION F_GET_PMDA_SRID (PI_CASE_ID         IN NUMBER,
                              PI_REG_REPORT_ID   IN NUMBER,
                              PI_AGENCY_ID       IN NUMBER,
                              PI_PREV_REPORT     IN NUMBER)
        RETURN VARCHAR2
    IS
        --******************************************************************************************
        --** Purpose:  This function is used to generate safetyreportid for pmda.
        --** Inputs:   PI_CASE_ID
        --**           PI_REG_REPORT_ID
        --**           PI_AGENCY_ID
        --** Output:   Output should be a VARCHAR2 safetyreportid
        --******************************************************************************************
        l_initial               NUMBER := 0;
        l_oob_srid              VARCHAR2 (100) := NULL;
        l_company_name          VARCHAR2 (100) := NULL;
        l_custom_srid           CASE_MASTER.E2B_WW_NUMBER%TYPE := NULL;
        L_WW_ID                 CASE_MASTER.E2B_WW_NUMBER%TYPE;
        l_prev_safetyreportid   CASE_MASTER.E2B_WW_NUMBER%TYPE := NULL;
        V_SQLERRM               VARCHAR2 (4000);
        l_migrated_case         NUMBER := 0;
    BEGIN
        l_custom_srid := NULL;

        SELECT DECODE (followup_num, 0, 1, 0)
          INTO l_initial
          FROM CMN_REG_REPORTS
         WHERE reg_report_id = pi_reg_report_id;

        SELECT COUNT (1)
          INTO l_migrated_case
          FROM case_reference
         WHERE     case_id = PI_CASE_ID
               AND ref_type_id IN
                       (SELECT REF_TYPE_ID
                          FROM LM_REF_TYPES
                         WHERE UPPER (TYPE_DESC) IN
                                   ('E2B COMPANY NUMBER-JAPAN'));

        SELECT cont_company_name
          INTO l_company_name
          FROM lm_regulatory_contact
         WHERE agency_id = pi_agency_id;

        SELECT MIN (safetyreportid)
          INTO l_prev_safetyreportid
          FROM safetyreport
         WHERE report_id = pi_prev_report;

        l_oob_srid :=
            ESM_UTL.F_GET_PMDA_E2B_WW_NUMBER (PI_CASE_ID,
                                              PI_AGENCY_ID,
                                              PI_REG_REPORT_ID,
                                              'SAFETYREPORTID');

        IF    l_migrated_case > 0 AND (l_initial = 1)
           OR (    (l_initial = 0)
               AND (l_oob_srid <> NVL (l_prev_safetyreportid, 'ZZ')))
        THEN
            IF INSTR (l_oob_srid, l_company_name) = 0
            THEN
                L_WW_ID := NULL;

                BEGIN
                    SELECT UPPER (
                                  A2
                               || '-'
                               || LRC.CONT_COMPANY_NAME
                               || '-'
                               || CM.CASE_NUM)
                      INTO L_WW_ID
                      FROM LM_COUNTRIES           LC,
                           LM_REGULATORY_CONTACT  LRC,
                           CASE_MASTER            CM
                     WHERE     LC.COUNTRY_ID =
                               (SELECT DECODE (
                                           CR.COUNTRY_ID,
                                           -1, (SELECT CM1.COUNTRY_ID
                                                  FROM CASE_MASTER CM1
                                                 WHERE CM1.CASE_ID =
                                                       PI_CASE_ID),
                                           NULL, (SELECT CM2.COUNTRY_ID
                                                    FROM CASE_MASTER CM2
                                                   WHERE CM2.CASE_ID =
                                                         PI_CASE_ID),
                                           CR.COUNTRY_ID)
                                  FROM CASE_REPORTERS  CR,
                                       CASE_MASTER     CM,
                                       (SELECT COUNT (*) CNT
                                          FROM CASE_REPORTERS
                                         WHERE CASE_ID = PI_CASE_ID) A
                                 WHERE     CM.CASE_ID = PI_CASE_ID
                                       AND CR.CASE_ID(+) = CM.CASE_ID
                                       AND CR.DELETED IS NULL
                                       AND (   (    A.CNT > 1
                                                AND DECODE (
                                                        CR.PRIMARY_CONTACT,
                                                        -1, 1,
                                                        CR.PRIMARY_CONTACT) =
                                                    1)
                                            OR (    A.CNT < 2
                                                AND DECODE (
                                                        CR.PRIMARY_CONTACT,
                                                        -1, 1,
                                                        CR.PRIMARY_CONTACT) =
                                                    1)
                                            OR (    A.CNT > 1
                                                AND CR.PRIMARY_CONTACT = 1)
                                            OR (    A.CNT < 2
                                                AND NVL (CR.PRIMARY_CONTACT,
                                                         1) =
                                                    1)))
                           AND LRC.AGENCY_ID = PI_AGENCY_ID
                           AND CM.CASE_ID = PI_CASE_ID;

                    IF L_WW_ID IS NOT NULL
                    THEN
                        l_custom_srid := L_WW_ID || 'AA';
                    ELSE
                        l_custom_srid := NULL;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_custom_srid := NULL;
                    WHEN OTHERS
                    THEN
                        l_custom_srid := NULL;
                END;
            ELSE
                l_custom_srid := l_oob_srid;                --Return OOB value
            END IF;
        ELSE
            l_custom_srid := l_oob_srid;
        END IF;

        RETURN l_custom_srid;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END F_GET_PMDA_SRID;

    --*************************************************************************************************
    --** Name:       F_FULFILL_EXP_CRITERIA_LLY                                                  **
    --**                                                                                             **
    --** Created by: Kunal Dudeja                                                                 **
    --**                                                                                             **
    --** Creation date: 20/07/2018                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic for FULFILLEXPEDITECRITERIAR3 dtd_element                              **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**        PI_REG_REPORT_ID -  It is the ID used to reference the report                        **
    --**                                                                                             **
    --** Outputs: NUMBER                                   **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Kunal Dudeja       20-JUL-2018  CHG1197301  Created                                         **
    --*************************************************************************************************

    FUNCTION F_FULFILL_EXP_CRITERIA_LLY (PI_CASE_ID          NUMBER,
                                         PI_REG_REPORT_ID    NUMBER)
        RETURN NUMBER
    IS
        L_RET_VAL         NUMBER := NULL;
        V_RPT_CATEGORY    LM_RPT_CATEGORY.RPT_CATEGORY%TYPE := NULL;
        L_NULLIFICATION   NUMBER := NULL;
        L_LIC_TYPE_ID     NUMBER := NULL;
        L_TIMEFRAME       CMN_REG_REPORTS.TIMEFRAME%TYPE := NULL;
    BEGIN
        BEGIN
            SELECT NVL (CMN.NULLIFICATION, 0),
                   NVL (LL.LICENSE_TYPE_ID, 0),
                   NVL (CMN.TIMEFRAME, 0),
                   LRC.RPT_CATEGORY
              INTO L_NULLIFICATION,
                   L_LIC_TYPE_ID,
                   L_TIMEFRAME,
                   V_RPT_CATEGORY
              FROM CMN_REG_REPORTS    CMN,
                   LM_LICENSE         LL,
                   CASE_PMDA_LICENSE  CPL,
                   LM_RPT_CATEGORY    LRC
             WHERE     CMN.REG_REPORT_ID = PI_REG_REPORT_ID
                   AND CMN.LICENSE_ID = LL.LICENSE_ID
                   AND CPL.CASE_ID = PI_CASE_ID
                   AND CMN.LICENSE_ID = CPL.LICENSE_ID
                   AND CMN.PROD_SEQ_NUM = CPL.PROD_SEQ_NUM
                   AND CPL.RPT_CATEGORY_ID = LRC.RPT_CATEGORY_ID;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
        END;

        IF V_RPT_CATEGORY = 'G'
        THEN
            RETURN 1;
        END IF;

        IF L_NULLIFICATION = 1
        THEN
            RETURN 2;
        ELSIF L_NULLIFICATION = 2
        THEN
            RETURN 2;
        END IF;

        IF V_RPT_CATEGORY IN ('E',
                              'F',
                              'L',
                              'M',
                              'N',
                              'O',
                              'P')
        THEN
            L_RET_VAL := 2;
        ELSE
            IF L_LIC_TYPE_ID > 0 AND L_LIC_TYPE_ID < 4
            THEN
                IF L_TIMEFRAME <= 7
                THEN
                    L_RET_VAL := 1;
                ELSE
                    L_RET_VAL := 2;
                END IF;
            ELSIF L_LIC_TYPE_ID > 3 AND L_LIC_TYPE_ID < 7
            THEN
                IF L_TIMEFRAME <= 15
                THEN
                    L_RET_VAL := 1;
                ELSE
                    L_RET_VAL := 2;
                END IF;
            END IF;
        END IF;

        RETURN L_RET_VAL;
    END F_FULFILL_EXP_CRITERIA_LLY;

    --*************************************************************************************************
    --** Name:       F_IS_NUMBER                                                                     **
    --**                                                                                             **
    --** Created by: Kunal Dudeja                                                                    **
    --**                                                                                             **
    --** Creation date: 20/07/2018                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic for TEST dtd_element                                                   **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_STR - It is used to input lab test result string                                 **
    --**                                                                                             **
    --** Outputs: NUMBER                                                                             **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Kunal Dudeja       20-JUL-2018  CHG1197301  Created                                         **
    --*************************************************************************************************

    FUNCTION F_IS_NUMBER (PI_STR IN VARCHAR2)
        RETURN NUMBER
    IS
        DUMMY   NUMBER;
    BEGIN
        DUMMY := TO_NUMBER (PI_STR);
        RETURN 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --*************************************************************************************************
    --** Name:       p_esm_import                                                                     **
    --**                                                                                             **
    --** Created by: Kunal Dudeja                                                                    **
    --**                                                                                             **
    --** Creation date: 20/07/2018                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic to insert sender as reporter                                           **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID - It is used to input Case ID                                            **
    --**        PI_RPT_SERIOUS -  Event Reported seriosness input                                    **
    --**        PI_SEQ_NUM -  Event seq number                                       **
    --**                                                                                             **
    --** Outputs: NUMBER                                                                             **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Kunal Dudeja       20-JUL-2018  CHG1197301  Created                                         **
    --*************************************************************************************************

    FUNCTION F_TERMHIGHLIGHTED (PI_CASE_ID       IN NUMBER,
                                PI_RPT_SERIOUS   IN NUMBER,
                                PI_SEQ_NUM       IN NUMBER)
        RETURN NUMBER
    IS
        L_CRITERIA   NUMBER;
    BEGIN
        SELECT DECODE (
                   NVL (
                       SUM (
                             DECODE (SC_DEATH, 1, 1, 0)
                           + DECODE (SC_HOSP, 1, 1, 0)
                           + DECODE (SC_CONG_ANOM, 1, 1, 0)
                           + DECODE (SC_THREAT, 1, 1, 0)
                           + DECODE (SC_DISABLE, 1, 1, 0)
                           + DECODE (MED_SERIOUS, 1, 1, 0)
                           + DECODE (SC_OTHER, 1, 1, 0)),
                       0),
                   0, 0,
                   1)
          INTO L_CRITERIA
          FROM CASE_EVENT
         WHERE CASE_ID = PI_CASE_ID AND SEQ_NUM = PI_SEQ_NUM;

        IF PI_RPT_SERIOUS = -1
        THEN
            RETURN NULL;
        END IF;

        IF PI_RPT_SERIOUS = 1 AND L_CRITERIA = 1
        THEN
            RETURN 3;
        ELSIF PI_RPT_SERIOUS = 0 AND L_CRITERIA = 1
        THEN
            RETURN 4;
        ELSIF PI_RPT_SERIOUS = 1 AND L_CRITERIA = 0
        THEN
            RETURN 1;
        ELSIF PI_RPT_SERIOUS = 0 AND L_CRITERIA = 0
        THEN
            RETURN 2;
        ELSE
            RETURN 2;
        END IF;
    END;

    --*************************************************************************************************
    --** Name:       F_GET_SENDER_COMMENT                                                            **
    --**                                                                                             **
    --** Created by: Kunal Dudeja                                                                    **
    --**                                                                                             **
    --** Creation date: 15/01/2019                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic to custo,ize SUMMARY tag for R3 profile                                **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: PI_CASE_ID                                                                          **
    --**        PI_LENGTH                                                                            **
    --**                                                                                             **
    --** Outputs: CLOB                                                                               **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Kunal Dudeja       15-JAN-2019  CHG1197301  Created                                         **
    --*************************************************************************************************

    FUNCTION F_GET_SENDER_COMMENT (PI_CASE_ID NUMBER, PI_LENGTH NUMBER)
        RETURN CLOB
    AS
        L_OUTPUT       CLOB;
        L_TEMP_VALUE   VARCHAR2 (32767);
    BEGIN
        SELECT ESM_UTL.F_RETURN_CLOB_MAX_32000 (case_comments.COMMENT_TXT,
                                                PI_LENGTH)
          INTO L_OUTPUT
          FROM CASE_MASTER, case_comments
         WHERE     CASE_MASTER.CASE_ID = PI_CASE_ID
               AND CASE_MASTER.CASE_ID = case_comments.CASE_ID(+);

        IF (DBMS_LOB.GETLENGTH (L_OUTPUT) = PI_LENGTH)
        THEN
            RETURN L_OUTPUT;
        END IF;

        FOR Z
            IN (  SELECT REF_NO, NOTES
                    FROM CASE_REFERENCE
                   WHERE     CASE_ID = PI_CASE_ID
                         AND REF_TYPE_ID IN (1, 2, 18)
                         AND (REF_NO IS NOT NULL OR NOTES IS NOT NULL)
                ORDER BY SORT_ID)
        LOOP
            L_OUTPUT :=
                   L_OUTPUT
                || CHR (13)
                || CHR (10)
                || Z.REF_NO
                || ':'
                || Z.NOTES;

            IF (DBMS_LOB.GETLENGTH (L_OUTPUT) >= PI_LENGTH)
            THEN
                EXIT;
            END IF;
        END LOOP;

        RETURN ESM_UTL.F_RETURN_CLOB_MAX_32000 (L_OUTPUT, PI_LENGTH);
    END F_GET_SENDER_COMMENT;

    FUNCTION F_GET_PMDA_COMPANYNUMB (PI_CASE_ID         IN NUMBER,
                                     PI_REG_REPORT_ID   IN NUMBER,
                                     PI_AGENCY_ID       IN NUMBER,
                                     PI_PREV_REPORT     IN NUMBER)
        RETURN VARCHAR2
    IS
        --******************************************************************************************
        --** Purpose:  This function is used to generate companynumb for pmda.
        --** Inputs:   PI_CASE_ID
        --**           PI_REG_REPORT_ID
        --**           PI_AGENCY_ID
        --** Output:   Output should be a VARCHAR2 companynumb
        --******************************************************************************************
        l_prev_safetyreportid   CASE_MASTER.E2B_WW_NUMBER%TYPE := NULL;
        l_prev_compnynumb       safetyreport.companynumb%TYPE := NULL;
        l_prev_authoritynumb    safetyreport.authoritynumb%TYPE := NULL;
        l_profile               safetyreport.profile%TYPE := NULL;
        l_ref_no                CASE_REFERENCE.ref_no%TYPE := NULL;
    BEGIN
        BEGIN
            SELECT COMPANYNUMB, AUTHORITYNUMB, PROFILE
              INTO l_prev_compnynumb, l_prev_authoritynumb, l_profile
              FROM SAFETYREPORT
             WHERE REPORT_ID = PI_PREV_REPORT;
        EXCEPTION
            WHEN OTHERS
            THEN
                L_PREV_SAFETYREPORTID := NULL;
                L_PREV_COMPNYNUMB := NULL;
                L_PREV_AUTHORITYNUMB := NULL;
                l_profile := NULL;
        END;

        IF (L_PROFILE IN
                ('ICH-ICSR V2.1 MESSAGE TEMPLATE - PMDA - I - LLY',
                 'ICH-ICSR V2.1 MESSAGE TEMPLATE - PMDA - J - LLY'))
        THEN
            IF L_PREV_AUTHORITYNUMB IS NOT NULL
            THEN
                L_REF_NO := L_PREV_AUTHORITYNUMB;
            END IF;

            IF L_PREV_COMPNYNUMB IS NOT NULL AND L_REF_NO IS NULL
            THEN
                L_REF_NO := l_prev_compnynumb;
            END IF;
        END IF;

        IF (    L_PROFILE IN ('ICH-ICSR V3.0 MESSAGE TEMPLATE - PMDA - LLY')
            AND L_REF_NO IS NULL)
        THEN
            L_REF_NO := l_prev_compnynumb;
        END IF;

        IF L_PROFILE IS NULL AND L_REF_NO IS NULL
        THEN
            BEGIN
                SELECT REF_NO
                  INTO l_REF_NO
                  FROM CASE_REFERENCE_ARGUS
                 WHERE     CASE_ID = PI_CASE_ID
                       AND REF_TYPE_ID =
                           (SELECT ref_type_id
                              FROM argus_app.lm_ref_types
                             WHERE type_desc = 'E2B Authority Number')
                       AND SEQ_NUM =
                           (SELECT MIN (SEQ_NUM)
                              FROM CASE_REFERENCE_ARGUS
                             WHERE     CASE_ID = PI_CASE_ID
                                   AND REF_TYPE_ID =
                                       (SELECT ref_type_id
                                          FROM argus_app.lm_ref_types
                                         WHERE type_desc =
                                               'E2B Authority Number'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    L_REF_NO := NULL;
            END;

            IF (L_REF_NO IS NULL)
            THEN
                SELECT REF_NO
                  INTO l_REF_NO
                  FROM CASE_REFERENCE_ARGUS
                 WHERE     CASE_ID = PI_CASE_ID
                       AND REF_TYPE_ID =
                           (SELECT ref_type_id
                              FROM argus_app.lm_ref_types
                             WHERE type_desc = 'E2B Company Number')
                       AND SEQ_NUM =
                           (SELECT MIN (SEQ_NUM)
                              FROM CASE_REFERENCE_ARGUS
                             WHERE     CASE_ID = PI_CASE_ID
                                   AND REF_TYPE_ID =
                                       (SELECT ref_type_id
                                          FROM argus_app.lm_ref_types
                                         WHERE type_desc =
                                               'E2B Company Number'));
            END IF;
        END IF;

        RETURN L_REF_NO;
    END F_GET_PMDA_COMPANYNUMB;

    FUNCTION F_GET_PMDA_CASESENDERTYPE (PI_CASE_ID         IN NUMBER,
                                        PI_REG_REPORT_ID   IN NUMBER,
                                        PI_AGENCY_ID       IN NUMBER,
                                        PI_PREV_REPORT     IN NUMBER)
        RETURN NUMBER
    IS
        --******************************************************************************************
        --** Purpose:  This function is used to generate casesendertype for pmda.
        --** Inputs:   PI_CASE_ID
        --**           PI_REG_REPORT_ID
        --**           PI_AGENCY_ID
        --** Output:   Output should be a NUMBER casesendertype
        --******************************************************************************************
        l_prev_safetyreportid   CASE_MASTER.E2B_WW_NUMBER%TYPE := NULL;
        l_prev_compnynumb       safetyreport.companynumb%TYPE := NULL;
        l_prev_authoritynumb    safetyreport.authoritynumb%TYPE := NULL;
        L_PROFILE               SAFETYREPORT.PROFILE%TYPE := NULL;
        L_CASESENDERTYPE_RPT    SAFETYREPORT.CASESENDERTYPE%TYPE := NULL;
        L_CASESENDERTYPE        NUMBER := 0;
    BEGIN
        BEGIN
            SELECT SAFETYREPORTID,
                   COMPANYNUMB,
                   AUTHORITYNUMB,
                   PROFILE,
                   CASESENDERTYPE
              INTO l_prev_safetyreportid,
                   l_prev_compnynumb,
                   l_prev_authoritynumb,
                   l_profile,
                   l_CASESENDERTYPE_rpt
              FROM SAFETYREPORT
             WHERE REPORT_ID = PI_PREV_REPORT;
        EXCEPTION
            WHEN OTHERS
            THEN
                L_PREV_SAFETYREPORTID := NULL;
                L_PREV_COMPNYNUMB := NULL;
                L_PREV_AUTHORITYNUMB := NULL;
                l_profile := NULL;
        END;

        IF (L_PROFILE IS NOT NULL)
        THEN
            IF (L_PREV_AUTHORITYNUMB IS NOT NULL)
            THEN
                L_CASESENDERTYPE := 1;
            END IF;

            IF (l_prev_compnynumb IS NOT NULL)
            THEN
                L_CASESENDERTYPE := 2;
            END IF;
        END IF;

        IF (L_CASESENDERTYPE = 0)
        THEN
            SELECT CASE WHEN COUNT (1) = 0 THEN 2 ELSE 1 END
              INTO L_CASESENDERTYPE
              FROM CASE_REFERENCE_ARGUS
             WHERE CASE_ID = PI_CASE_ID AND REF_TYPE_ID = 15;
        END IF;

        RETURN L_CASESENDERTYPE;
    END F_GET_PMDA_CASESENDERTYPE;

    --*************************************************************************************************
    --** Name:       p_esm_import                                                                     **
    --**                                                                                             **
    --** Created by: Kunal Dudeja                                                                    **
    --**                                                                                             **
    --** Creation date: 31/08/2018                                                                   **
    --**                                                                                             **
    --** Purpose:Custom logic to insert sender as reporter                                           **
    --**                                                                                             **
    --**                                                                                             **
    --** Inputs: pi_enterprise_id                                                                    **
    --**        PI_REG_REPORT_ID -  It is the ID used to reference the report                        **
    --**                                                                                             **
    --** Outputs: NUMBER                                                                             **
    --**                                                                                             **
    --** Modification History:                                                                       **
    --** Kunal Dudeja       31-AUG-2018  CHG1197301  Created       **
    --** Kunal Dudeja       10-MAY-2019  CHG1423473  Modified        **
    --** Kanchan Gupta      13-JUN-2019  CHG1423473  added comments                                  **
    --*************************************************************************************************

    PROCEDURE p_esm_import (pi_report_id NUMBER, pi_enterprise_id NUMBER)
    IS
        L_SAFETYREPORTID        VARCHAR2 (2000);
        l_agency_id             NUMBER := 0;
        l_case_id               NUMBER;
        L_SENDERTYPE            NUMBER;
        L_SENDERORGANIZATION    VARCHAR2 (2000);
        L_SENDERSTREETADDRESS   VARCHAR2 (2000);
        L_SENDERCITY            VARCHAR2 (100);
        L_SENDERSTATE           VARCHAR2 (100);
        L_SENDERCOUNTRYCODE     VARCHAR2 (100);
        L_SENDERTELR3           VARCHAR2 (100);
        --L_SENDERTELEXTENSION varchar2(100);
        L_SENDERFAX             VARCHAR2 (100);
        L_SENDEREMAILADDRESS    VARCHAR2 (100);
        L_SENDERPOSTCODE        VARCHAR2 (100);
        L_SENDERDEPARTMENT      VARCHAR2 (100);
        L_SENDERTITLE           VARCHAR2 (100);
        L_SENDERGIVENAME        VARCHAR2 (100);
        L_SENDERMIDDLENAME      VARCHAR2 (100);
        L_SENDERFAMILYNAME      VARCHAR2 (100);
        l_seq_num               NUMBER := 0;
        l_sort_id               NUMBER := 0;
        l_country               VARCHAR2 (100);
        l_country_id            NUMBER;
        l_e2b_type              NUMBER;
        l_E2B_TYPE_ACCEPT_AS    NUMBER;
    BEGIN
        BEGIN
            SELECT safetyreportid,
                   agency_id,
                   e2b_type,
                   E2B_TYPE_ACCEPT_AS
              INTO l_safetyreportid,
                   l_agency_id,
                   l_e2b_type,
                   l_E2B_TYPE_ACCEPT_AS
              FROM esm_owner.safetyreport
             WHERE     REPORT_ID = PI_REPORT_ID
                   AND AGENCY_ID IN
                           (SELECT AGENCY_ID
                              FROM LM_REGULATORY_CONTACT
                             WHERE UPPER (AGENCY_NAME) IN
                                       ('EU EMA - POSTMKT - E2B',
                                        'EU EMA - CT - E2B',
                                        'EU EUDRAVIGILANCE R3 E2B',
                                        'EU EUDRAVIGILANCE MLM R3 E2B',
                                        'MOSAIC'));

            SELECT DISTINCT case_xref
              INTO l_case_id
              FROM esm_owner.safetyreport s, argus_app.case_master cm
             WHERE     s.safetyreportid = l_safetyreportid
                   AND s.agency_id = l_agency_id
                   AND s.e2b_type IN (1, 3)
                   AND s.status = 102
                   AND cm.case_id = s.case_xref;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_case_id := -1;
        END;

        BEGIN
            SELECT SENDERSTATE
              INTO L_SENDERSTATE
              FROM esm_owner.lss_sender_data
             WHERE REPORT_ID = PI_REPORT_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                L_SENDERSTATE := NULL;
        END;

        IF (l_case_id > 0 AND l_agency_id > 0)
        THEN
            BEGIN
                SELECT SENDERTYPE,
                       SENDERORGANIZATION,
                       SENDERSTREETADDRESS,
                       SENDERCITY,
                       SENDERSTATE,
                       SENDERCOUNTRYCODE,
                       SENDERTELR3,
                       SENDERFAX,
                       SENDEREMAILADDRESS,
                       SENDERPOSTCODE,
                       SENDERDEPARTMENT,
                       SENDERTITLE,
                       SENDERGIVENAME,
                       SENDERMIDDLENAME,
                       SENDERFAMILYNAME
                  INTO L_SENDERTYPE,
                       L_SENDERORGANIZATION,
                       L_SENDERSTREETADDRESS,
                       L_SENDERCITY,
                       L_SENDERSTATE,
                       L_SENDERCOUNTRYCODE,
                       L_SENDERTELR3,
                       L_SENDERFAX,
                       L_SENDEREMAILADDRESS,
                       L_SENDERPOSTCODE,
                       L_SENDERDEPARTMENT,
                       L_SENDERTITLE,
                       L_SENDERGIVENAME,
                       L_SENDERMIDDLENAME,
                       L_SENDERFAMILYNAME
                  FROM esm_owner.lss_sender_data
                 WHERE report_id = pi_report_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_sendertype := 0;
            END;

            IF (    L_SENDERTYPE IN (1, 2)
                AND NVL (l_E2B_TYPE_ACCEPT_AS, l_e2b_type) = 1)
            THEN
                SELECT argus_app.s_case_reporters.NEXTVAL
                  INTO l_seq_num
                  FROM DUAL;

                BEGIN
                    SELECT COUNTRY, COUNTRY_ID
                      INTO l_country, l_country_id
                      FROM lm_countries
                     WHERE a2 = L_SENDERCOUNTRYCODE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_country := NULL;
                        l_country_id := NULL;
                END;

                BEGIN
                    SELECT MAX (SORT_ID) + 1
                      INTO L_SORT_ID
                      FROM argus_app.case_reporters
                     WHERE case_id = l_case_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_sort_id := 1;
                END;

                INSERT INTO argus_app.case_reporters (case_id,
                                                      seq_num,
                                                      hcp_flag,
                                                      primary_contact,
                                                      sort_id,
                                                      Institution,
                                                      Department,
                                                      prefix,
                                                      first_name,
                                                      middle_name,
                                                      LAST_NAME,
                                                      COUNTRY_ID,
                                                      address,
                                                      city,
                                                      state,
                                                      postcode,
                                                      country,
                                                      phone,
                                                      altphone,
                                                      email)
                     VALUES (l_case_id,
                             l_seq_num,
                             0,
                             0,
                             l_sort_id,
                             L_SENDERORGANIZATION,
                             L_SENDERDEPARTMENT,
                             L_SENDERTITLE,
                             L_SENDERGIVENAME,
                             L_SENDERMIDDLENAME,
                             L_SENDERFAMILYNAME,
                             l_COUNTRY_ID,
                             L_SENDERSTREETADDRESS,
                             L_SENDERCITY,
                             L_SENDERSTATE,
                             L_SENDERPOSTCODE,
                             l_country,
                             l_country_id || ' ' || L_SENDERTELR3,
                             l_country_id || ' ' || L_SENDERFAX,
                             L_SENDEREMAILADDRESS);
            END IF;

            DELETE FROM esm_owner.lss_sender_data
                  WHERE report_id = pi_report_id;

            FOR rec
                IN (SELECT DISTINCT ced.rechallenge, cpd.seq_num
                      FROM case_event_detail ced, case_prod_drugs cpd
                     WHERE     ced.case_id = l_case_id
                           AND cpd.case_id = ced.case_id
                           AND cpd.seq_num = ced.prod_seq_num)
            LOOP
                UPDATE case_prod_drugs
                   SET rechallenge = rec.rechallenge
                 WHERE case_id = l_case_id AND seq_num = rec.seq_num;
            END LOOP;

            FOR rec
                IN (SELECT cea.case_id,
                           cea.event_seq_num,
                           cea.prod_seq_num,
                           cp.product_name,
                           ce.desc_reptd,
                           (SELECT causality
                              FROM lm_causality
                             WHERE     causality_id = cea.rpt_causality_id
                                   AND deleted IS NULL)
                               rpt_causality,
                           cea.rpt_causality_id,
                           (SELECT causality
                              FROM lm_causality
                             WHERE     causality_id = cea.det_causality_id
                                   AND deleted IS NULL)
                               det_causality,
                           cea.det_causality_id,
                           (SELECT source
                              FROM lm_causality_source
                             WHERE     source_id = cea.rpt_source_id
                                   AND deleted IS NULL)
                               rpt_source,
                           cea.rpt_source_id,
                           (SELECT source
                              FROM lm_causality_source
                             WHERE     source_id = cea.det_source_id
                                   AND deleted IS NULL)
                               det_source,
                           cea.det_source_id
                      FROM argus_app.case_event_assess  cea,
                           argus_app.case_product       cp,
                           argus_app.case_event         ce
                     WHERE     cea.license_id = 0
                           AND cea.datasheet_id = 0
                           AND cea.case_id = l_case_id
                           AND cea.case_id = cp.case_id
                           AND ce.case_id = cea.case_id
                           AND cea.event_seq_num = ce.seq_num
                           AND cea.prod_seq_num = cp.seq_num
                           AND cea.deleted IS NULL
                           AND cp.deleted IS NULL
                           AND ce.deleted IS NULL)
            LOOP
                BEGIN
                    --adding Determined causality details
                    IF    REC.DET_CAUSALITY IS NOT NULL
                       OR REC.DET_SOURCE IS NOT NULL
                    THEN
                        UPDATE argus_app.case_event
                           SET details =
                                      details
                                   || CHR (10)
                                   || 'Product Name > '
                                   || rec.product_name
                                   || ', Event Name > '
                                   || rec.desc_reptd
                                   || ', Causality as Reported Source - '
                                   || NVL (rec.rpt_source, '<blank>')
                                   || ', As Reported Causality Result - '
                                   || NVL (rec.rpt_causality, '<blank>')
                                   || ', Causality as Determined Source - '
                                   || NVL (rec.det_source, '<blank>')
                                   || ', As Determined Causality Result - '
                                   || NVL (rec.det_causality, '<blank>')
                         WHERE     case_id = rec.case_id
                               AND sort_id = 1
                               AND deleted IS NULL;
                    END IF;
                END;
            END LOOP;
        END IF;
    END p_esm_import;
END;
/
