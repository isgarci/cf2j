#!/bin/bash

:'
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
'

function cfmlToJavaSignature {
	infile=$1
	filename=${infile##*/}
	out=$2
	outfolder=${out%/*}

	IS_INTERFACE=`grep -i 'interface *' $infile | grep -i '">' | wc -l`
	
	if [ $IS_INTERFACE -gt 0 ]
	then	
		echo "interface ""${filename%%.*}" > $out
	else
		echo "class ""${filename%%.*}" > $out
	fi	

	grep -i "implements=" $infile | awk -F"implements=\"" '{print "implements " $2 }' | sed -i 's/">//' >> $out 	
	echo "{ ">> $out 	

	FUNCTION_FILES_PREF=$outfolder"/"$filename._function
	csplit -f $FUNCTION_FILES_PREF $infile '/<cffunction/' '{*}' 
	FUNCTION_FILES=${FUNCTION_FILES_PREF}*
	for ff in $FUNCTION_FILES
	do 
		#echo intermezzofil_ :$ff
		FUNC_NAME_LINE=$(grep -oP '(?<=cffunction name=").*?(?=")' $ff)
		FUNC_NAME_LINE="${FUNC_NAME_LINE#"${FUNC_NAME_LINE%%[![:space:]]*}"}" 	# remove leading whitespace characters
		FUNC_NAME_LINE="${FUNC_NAME_LINE%"${FUNC_NAME_LINE##*[![:space:]]}"}" 	# remove trailing whitespace characters
		if [ -n "$FUNC_NAME_LINE" ] 
		then 
			#echo FUNC_NAME_LINE til $ff: $FUNC_NAME_LINE
			#echo -n '\tpublic ' >> $out
			RETURN_TYPE="$(grep -oP '(?<=returntype=").*?(?=\")' $ff)"
			#echo RETURN_TYPE: $RETURN_TYPE
			echo -n $RETURN_TYPE >> $out #prints return type
			echo -n " "$FUNC_NAME_LINE" " >> $out 
			NUMARGS=$(grep cfargument $ff | wc -l)
			if [ $NUMARGS -gt 0 ]
			then
				ARGS=`grep cfargument $ff | awk -F"cfargument" '{print $2}' | awk -F"name=" '{print $2}' | awk -F"\"" '{print $4 " " $2 ","}'`
				ARGS="${ARGS%?}"
				#echo $ARGS
				echo -n "(" $ARGS ") { }" >> $out
			else 
				echo -n "() { }" >> $out
			fi
			printf "\n" >> $out
		fi
	done
	printf "}" >> $out
	rm $FUNCTION_FILES
}

function cfscriptToJavaSignature {
	infile=$1
	out=$2

	echo input:$infile
	echo output:$out	
	grep -i 'interface\|component\|property\|public\|private' $infile > $out
	sed -i 's/component/class/I' $out
	sed -i 's/displayname="//' $out      # replaces only 1st instance 
	sed -i 's/" {/"{/' $out
	sed -i 's/"[[:space:]]*{/ {/' $out            				# replaces only 1st instance 
	sed -i 's/property //g' $out           			# replaces ALL instances 
	sed -i 's/required //g' $out            # replaces ALL instances in a line
	sed -i 's/)[ \t]*{/) { }/g' $out
	sed -i 's/\([,]\)\([ \t]*\)\([[:alnum:]_-]\+\)\([ \t]*\)\([)]\)/,string \3)/g' $out
	sed -i 's/\([(]\)\([ \t]*\)\([[:alnum:]_-]\+\)\([ \t]*\)\([,]\)/(string \3,/g' $out
	sed -i 's/\([(]\)\([ \t]*\)\([[:alnum:]_-]\+\)\([ \t]*\)\([)]\)/(string \3)/g' $out
	sed -i 's/[ \t]*function[ \t]*/ /g' $out 
	sed -i '$ a }' $out	
}


if [ $# -eq 0 ]; then 
    echo "Syntax: cf2j [-o] destination_folder replacement_files..."
else
    if [ "$1" == "-o" ] || [ "$1" == "-O" ]; then
        OUTPUT_FOLDER=$2
        shift 2
    fi

	for f in "$@" 
	do
		infile=$f
		filename=${infile##*/}
		out=$OUTPUT_FOLDER"/"${filename%%.*}".java"

		#echo input_intermezzo: $infile
		#echo output_intermezzo: $out	

		IS_CFML_FILE=`grep -i '<cfcomponent *\|<cfinterface *' $infile | grep -i '">' | wc -l`
		IS_CFSCRIPT_FILE=`awk 'IGNORECASE = 1;/(component|interface)/{nr[NR]; nr[NR+1]}; NR in nr' $infile | grep '{' | wc -l`  # Works with breaked line component definition

		if [ $IS_CFML_FILE -gt 0 ]
		then
			cfmlToJavaSignature $infile $out
		elif [ $IS_CFML_FILE -eq 0 ] && [ $IS_CFSCRIPT_FILE -gt 0 ]
		then	
			cfscriptToJavaSignature $infile $out
		fi	
	done
fi