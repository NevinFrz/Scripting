if [ -n "$APP_DLL_NAME" ]; then
	if [ -n "$ISRELEASE" ]; then		
		if [ -n "$SECRET_FILE_PATH" ]; then secretfile="$SECRET_FILE_PATH"; else secretfile="../application/secrets.json"; fi
		source="../application/appsettings.release.json"
		if [ -n "$CONFIG_FILE_PATH" ]; then config="$CONFIG_FILE_PATH"; else config="../application.config"; fi				
		preconfig="../application/appsettings.pre.json"
		options="TC"
		ls
		cd /buildTools
		pwd
		if [ -n "$ASPNETCORE_ENVIRONMENT" ]; then
			#PERFORM APPSETTINGS TRANSFORM ONLY IF THIS VARIABLE IS SET
			if [ -n "$TRANSFORMCONFIG" ]; then
				echo "PROCESSING CONFIGS" 
				./appsettingstransformer $options $source $config	
				echo "PROCESSING SECRETS" 
				./appsettingstransformer $options $source $secretfile
				if [ -n "$source" ]; then
					echo "entered loop: source file below"
					cat $source
					echo "Config file below"
					cat $config
					echo "secretfile file below"
					cat $secretfile
				
					#appsettings=$(<$source)					
					cp $source ../application/appsettings.$ASPNETCORE_ENVIRONMENT.json
					cp $source ../application/appsettings.json
					echo "appsettings.json file below"
					cat ../application/appsettings.json
				else
					echo "Do Nothing"
				fi
			else
				echo "No transformation performed"
			fi
			cd ../application
			dotnet $APP_DLL_NAME
		else
			echo "Please provide applicatipn DLL name"
		fi
	else
		cd application
		dotnet $APP_DLL_NAME
	fi
else
      echo "Please provide application DLL name"
fi