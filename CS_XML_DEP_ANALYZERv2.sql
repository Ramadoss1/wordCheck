DO (OUT ret_tab TABLE(ROOT_VIEW NVARCHAR(255),	SCENARIO_NAME NVARCHAR(255))=>?)
BEGIN

	DECLARE ALL_SCENARIOS_ARR NVARCHAR(255) ARRAY;
	DECLARE ALL_OCC_ARR INTEGER ARRAY;
	DECLARE i INTEGER;
	DECLARE j INTEGER;
	DECLARE SCENARIO_NAME NVARCHAR(255);
	
	-- initialize
	FIN = SELECT '' as "ROOT_VIEW",
				 '' as "SCENARIO_NAME" FROM DUMMY;
		
		
	VIEWS_TO_BE_INSPECTED = 
	
	SELECT SCENARIO_NAME, OCCURENCES_DBV  FROM  (

		SELECT '_SYS_BIC:' || "PACKAGE_ID" ||'/'|| "OBJECT_NAME" AS "SCENARIO_NAME", 
				OCCURRENCES_REGEXPR( 'DATA_BASE_VIEW' IN CDATA) "OCCURENCES_DBV"
		FROM "_SYS_REPO"."ACTIVE_OBJECT" 
		WHERE "PACKAGE_ID" not like '%sap%'
		AND OBJECT_SUFFIX = 'calculationview'
	
	) WHERE  OCCURENCES_DBV > 0 ;
	
	ALL_SCENARIOS_ARR = ARRAY_AGG(:VIEWS_TO_BE_INSPECTED.SCENARIO_NAME);
	ALL_OCC_ARR = ARRAY_AGG(:VIEWS_TO_BE_INSPECTED.OCCURENCES_DBV);	
	
	FOR i IN 1 .. CARDINALITY(:ALL_SCENARIOS_ARR) DO -- Get the runtimeview name by searching through the xml of all views previously identified views (false positive results until here possible)
	
		FOR j IN 1 .. :ALL_OCC_ARR[:i] DO -- Search for Nth-occurence of runtime view in XML, we may have more then one runtimeview used
			
			SCENARIO_NAME = :ALL_SCENARIOS_ARR[:i];	
			
			TMP_TBL = SELECT :SCENARIO_NAME AS "ROOT_VIEW", '_SYS_BIC:' ||
			    SUBSTR_BEFORE(SUBSTR_AFTER(SUBSTRING(SUBSTRING(CDATA,LOCATE(CDATA,'"DATA_BASE_VIEW"',0,:j),512), -- position of type tag 
				LOCATE(SUBSTRING(CDATA,LOCATE(CDATA,'"DATA_BASE_VIEW"',0,:j),512)-- Stringbuffer starting at the datasource type tag until the columnObjectName tag
			    	,'columnObjectName="',0,1),512),'"' ),'"')
			    	as "SCENARIO_NAME" 
				FROM ( SELECT "PACKAGE_ID" ||'/'|| "OBJECT_NAME" AS "SCENARIO_NAME", 
					CDATA
					FROM "_SYS_REPO"."ACTIVE_OBJECT" 
					WHERE "PACKAGE_ID" not like '%sap%'
					AND OBJECT_SUFFIX = 'calculationview'
			) AS X WHERE X.SCENARIO_NAME = REPLACE(:SCENARIO_NAME,'_SYS_BIC:','');

			-- merge current and old results together
			FIN = SELECT * FROM :TMP_TBL
				  UNION ALL 
				  SELECT * FROM :FIN;			
		
		END FOR;	
				
	END FOR;

	RET_TAB = SELECT DISTINCT A."ROOT_VIEW",  A."SCENARIO_NAME" FROM :FIN as A
	;
END;