#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}

set +e
set +x 





function dra_commands {
    echo -e "${no_color}"
    dra_grunt_command=""
    
    if [ -n "$1" ] && [ "$1" != " " ]; then
        debugme echo "Event: '$1' is defined and not empty"
        
        dra_grunt_command="grunt --gruntfile=node_modules/grunt-idra2/idra.js -eventType=$1"
        
        debugme echo -e "\tdra_grunt_command: $dra_grunt_command"
        
        if [ -n "$2" ] && [ "$2" != " " ]; then
            debugme echo -e "\tFile: '$2' is defined and not empty"
            
            dra_grunt_command="$dra_grunt_command -file=$2"
        
            debugme echo -e "\t\tdra_grunt_command: $dra_grunt_command"
            
        else
            debugme echo -e "File: '$2' is not defined or is empty"
            debugme echo -e "${no_color}"
        fi
        #if [ -n "$3" ] && [ "$3" != " " ]; then
        #    echo -e "\tServer: '$3' is defined and not empty"
        #
        #    dra_grunt_command="$dra_grunt_command -deployAnalyticsServer=$3"
        #
        #    echo -e "\t\tdra_grunt_command: $dra_grunt_command"
        #
        #else
        #    echo -e "\tServer: '$3' is not defined or is empty"
        #fi
        
        debugme echo -e "FINAL dra_grunt_command: $dra_grunt_command"
        debugme echo -e "${no_color}"
        
        
        eval "$dra_grunt_command --no-color"
        GRUNT_RESULT=$?
        
        debugme echo "GRUNT_RESULT: $GRUNT_RESULT"
        
        if [ $GRUNT_RESULT -ne 0 ] && [ "${DRA_ADVISORY_MODE}" == "false" ]; then
            exit 1
        fi
    else
        debugme echo "Event: '$1' is not defined or is empty"
    fi
    
    echo -e "${no_color}"
}





if [ -z "$TOOLCHAIN_TOKEN" ]; then
    export CF_TOKEN=$(sed -e 's/^.*"AccessToken":"\([^"]*\)".*$/\1/' ~/.cf/config.json)
else
    export CF_TOKEN=$TOOLCHAIN_TOKEN
fi


OUTPUT_FILE='draserver.txt'
${EXT_DIR}/dra-check.py ${PIPELINE_TOOLCHAIN_ID} "${CF_TOKEN}" "${IDS_PROJECT_NAME}" "${OUTPUT_FILE}"
RESULT=$?

#0 = DRA is present
#1 = DRA not present or there was an error with the http call (err msg will show)
#echo $RESULT

if [ $RESULT -eq 0 ]; then
    debugme echo "DRA is present";
    
    echo -e "${green}"
    echo "**********************************************************************"
    echo "Deployment Risk Analytics (DRA) is active."
    echo "**********************************************************************"
    echo -e "${no_color}"
    
    export DRA_SERVER=`cat ${OUTPUT_FILE}`
    rm ${OUTPUT_FILE}

    debugme echo "DRA_SERVER: ${DRA_SERVER}"
fi







npm install grunt
npm install grunt-cli
npm install grunt-idra2


custom_cmd

echo -e "${no_color}"

debugme echo "DRA_ADVISORY_MODE: ${DRA_ADVISORY_MODE}"
debugme echo "DRA_TEST_TOOL_SELECT: ${DRA_TEST_TOOL_SELECT}"
debugme echo "DRA_TEST_LOG_FILE: ${DRA_TEST_LOG_FILE}"
debugme echo "DRA_MINIMUM_SUCCESS_RATE: ${DRA_MINIMUM_SUCCESS_RATE}"
debugme echo "DRA_CHECK_TEST_REGRESSION: ${DRA_CHECK_TEST_REGRESSION}"

debugme echo "DRA_COVERAGE_TOOL_SELECT: ${DRA_COVERAGE_TOOL_SELECT}"
debugme echo "DRA_COVERAGE_LOG_FILE: ${DRA_COVERAGE_LOG_FILE}"
debugme echo "DRA_MINIMUM_COVERAGE_RATE: ${DRA_MINIMUM_COVERAGE_RATE}"
debugme echo "DRA_CHECK_COVERAGE_REGRESSION: ${DRA_CHECK_COVERAGE_REGRESSION}"
debugme echo "DRA_COVERAGE_REGRESSION_THRESHOLD: ${DRA_COVERAGE_REGRESSION_THRESHOLD}"
debugme echo -e "${no_color}"







#0 = DRA is present
#1 = DRA not present or there was an error with the http call (err msg will show)
#echo $RESULT

if [ $RESULT -eq 0 ]; then
    debugme echo "DRA is present";
    
    
    criteriaList=()


    if [ -n "${DRA_TEST_TOOL_SELECT}" ] && [ "${DRA_TEST_TOOL_SELECT}" != "none" ] && \
        [ -n "${DRA_TEST_LOG_FILE}" ] && [ "${DRA_TEST_LOG_FILE}" != " " ]; then

        dra_commands "${DRA_TEST_TOOL_SELECT}UnitTest" "${DRA_TEST_LOG_FILE}"

        if [ -n "${DRA_MINIMUM_SUCCESS_RATE}" ] && [ "${DRA_MINIMUM_SUCCESS_RATE}" != " " ]; then
            name="At least ${DRA_MINIMUM_SUCCESS_RATE}% success in unit tests (${DRA_TEST_TOOL_SELECT})"
            criteria="{ \"name\": \"$name\", \"conditions\": [ { \"eval\": \"_mochaTestSuccessPercentage\", \"op\": \">=\", \"value\": ${DRA_MINIMUM_SUCCESS_RATE}, \"forEventType\": \"${DRA_TEST_TOOL_SELECT}UnitTest\" } ] }"

    #        if [ "${DRA_TEST_TOOL_SELECT}" == "mochaKarma" ]; then
    #            criteria="{ \"name\": \"$name\", \"conditions\": [ { \"eval\": \"_karmaMochaTestSuccessPercentage\", \"op\": \">=\", \"value\": ${DRA_MINIMUM_SUCCESS_RATE} } ] }"
    #        fi

            #echo "criteria:  $criteria"
            criteriaList=("${criteriaList[@]}" "$criteria")
        fi

        if [ -n "${DRA_CHECK_TEST_REGRESSION}" ] && [ "${DRA_CHECK_TEST_REGRESSION}" == "true" ]; then
            name="No Regression in Unit Tests (${DRA_TEST_TOOL_SELECT})"
            criteria="{ \"name\": \"$name\", \"conditions\": [ { \"eval\": \"_hasMochaTestRegressed\", \"op\": \"=\", \"value\": false, \"forEventType\": \"${DRA_TEST_TOOL_SELECT}UnitTest\" } ] }"

            if [ "${DRA_TEST_TOOL_SELECT}" == "mochaKarma" ]; then
                criteria="{ \"name\": \"$name\", \"conditions\": [ { \"eval\": \"_hasKarmaMochaTestRegressed\", \"op\": \"=\", \"value\": false, \"forEventType\": \"${DRA_TEST_TOOL_SELECT}UnitTest\" } ] }"
            fi

            #echo "criteria:  $criteria"
            criteriaList=("${criteriaList[@]}" "$criteria")
        fi
    fi

    if [ -n "${DRA_COVERAGE_TOOL_SELECT}" ] && [ "${DRA_COVERAGE_TOOL_SELECT}" != "none" ] && \
        [ -n "${DRA_COVERAGE_LOG_FILE}" ] && [ "${DRA_COVERAGE_LOG_FILE}" != " " ]; then

        dra_commands "${DRA_COVERAGE_TOOL_SELECT}Coverage" "${DRA_COVERAGE_LOG_FILE}"

        if [ -n "${DRA_MINIMUM_COVERAGE_RATE}" ] && [ "${DRA_MINIMUM_COVERAGE_RATE}" != " " ]; then
            name="At least ${DRA_MINIMUM_COVERAGE_RATE}% code coverage in unit tests (${DRA_COVERAGE_TOOL_SELECT})"

            condition_1="{ \"eval\": \"eventType\", \"op\": \"=\", \"value\": \"${DRA_COVERAGE_TOOL_SELECT}Coverage\", \"reportType\": \"CoverageResult\" }"
            condition_2="{ \"eval\": \"filecontents.total.lines.pct\", \"op\": \">=\", \"value\": \"${DRA_MINIMUM_COVERAGE_RATE}\", \"reportType\": \"CoverageResult\" }"

            if [ "${DRA_COVERAGE_TOOL_SELECT}" == "blanket" ]; then
                condition_1="{ \"eval\": \"eventType\", \"op\": \"=\", \"value\": \"${DRA_COVERAGE_TOOL_SELECT}Coverage\", \"reportType\": \"CoverageResult\" }"
                condition_2="{ \"eval\": \"filecontents.coverage\", \"op\": \">=\", \"value\": \"${DRA_MINIMUM_COVERAGE_RATE}\", \"reportType\": \"CoverageResult\" }"
            fi

            criteria="{ \"name\": \"$name\", \"conditions\": [ "
            criteria="$criteria $condition_1, $condition_2"
            criteria="$criteria ] }"

            #echo "criteria:  $criteria"
            criteriaList=("${criteriaList[@]}" "$criteria")
        fi

        if [ -n "${DRA_CHECK_COVERAGE_REGRESSION}" ] && [ "${DRA_CHECK_COVERAGE_REGRESSION}" == "true" ] &&  \
            [ -n "${DRA_COVERAGE_REGRESSION_THRESHOLD}" ] && [ "${DRA_COVERAGE_REGRESSION_THRESHOLD}" != " " ]; then
            name="No coverage regression in unit tests (${DRA_COVERAGE_TOOL_SELECT})"

            condition_1="{ \"eval\": \"_hasIstanbulCoverageRegressed(-${DRA_COVERAGE_REGRESSION_THRESHOLD})\", \"op\": \"=\", \"value\": false, \"forEventType\": \"${DRA_COVERAGE_TOOL_SELECT}Coverage\" }"

            if [ "${DRA_COVERAGE_TOOL_SELECT}" == "blanket" ]; then
                condition_1="{ \"eval\": \"_hasBlanketCoverageRegressed(-${DRA_COVERAGE_REGRESSION_THRESHOLD})\", \"op\": \"=\", \"value\": false, \"forEventType\": \"${DRA_COVERAGE_TOOL_SELECT}Coverage\" }"
            fi

            criteria="{ \"name\": \"$name\", \"conditions\": [ "
            criteria="$criteria $condition_1"
            criteria="$criteria ] }"

            #echo "criteria:  $criteria"
            criteriaList=("${criteriaList[@]}" "$criteria")
        fi
    fi


    if [ ${#criteriaList[@]} -gt 0 ]; then
        
        mode=""
        
        if [ "${DRA_ADVISORY_MODE}" == "false" ]; then
            mode="decision"
        else
            mode="advisory"
        fi
        
        criteria="{ \"name\": \"DynamicCriteria\", \"revision\": 2, \"project\": \"key\", \"mode\": \"$mode\", \"rules\": [ "

        for i in "${criteriaList[@]}"
        do
            criteria="$criteria $i,"
        done


        criteria="${criteria%?}"
        criteria="$criteria ] }"


        echo $criteria > dynamicCriteria.json

        debugme echo "Dynamic Criteria:"
        debugme cat dynamicCriteria.json

        echo -e "${no_color}"
        grunt --gruntfile=node_modules/grunt-idra2/idra.js -decision=dynamic -criteriafile=dynamicCriteria.json --no-color
        DECISION_RESULT=$?
        echo -e "${no_color}"
        
        return $DECISION_RESULT
    fi
else
    debugme echo "DRA is not present";
fi





