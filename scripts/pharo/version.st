"output Version Number of stdout"
FileStream stdout 
		nextPutAll: '[version] ';
		nextPutAll: SystemVersion current major asString;
		nextPutAll: '.';
		nextPutAll: SystemVersion current minor asString;
		nextPutAll: ' #' ;
		nextPutAll: SystemVersion current highestUpdate asString;
		cr.