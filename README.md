check_avaya_error_by_ossi
=========================

Query the alarms of the Definity Avaya S8xxx callmanager and check wheter the survivals are online

	Usage:
	Checks AVAYA S8xx components for callmanager- or serverfailures using
	OSSI protocol. You need to create a station file
	(pbx_connection_auth.xml) to the folder /usr/local/nagios/etc/avaya/
	<pbx-systems> <pbx name='n1' hostname='xxx.xxx.xxx.xxx' port='22'
	login='username' password='password' connection_type='ssh' atdt='' />
	</pbx-systems>
	 
	Options:
	check_avaya_error_by_ossi.pl -H <hostname> -S <LISU|CML> -L
	<MAJOR|MINOR|WARNING|ALL>
	 
	-H (--hostname)
	Hostname to query - (required)
	 
	-S (--service)
	LISU - List Survival, CML - Communicationmanagerlog
	 
	-L (--errorlevel)
	MAJOR, MINOR, WARNING, ALL (only -S = CML)
	 
	-i (--ignore)
	ignores Maintnames (only -S = CML), Array possible (Name,Name,Name)
	 
	-a (--alarmport)
	ignores Alarmports (only -S = CML), Array possible (Name,Name,Name)
	 
	-M (--changemajor)
	changes the status to major (only -S = CML), Array possible
	(Name,Name,Name)
	 
	-SL (--lspserverlist)
	An integer which let us know wheter the plugin should use a
	serverlist for LISU (1=TRUE, 0=FALSE) Then use the File LSPServer.pm
	to add the active server in an array (only -S = LISU)
	 
	-V (--version)
	Plugin version


More informations
-----------------
The plugin is working with the perl modul of Benjamin Roy <benroy@uw.edu> (http://tools.cac.washington.edu/2010/04/avaya-pbx-admin-web-service.html)
How to use the plugin read more in the gearman forum for Icinga / Nagios => http://www.monitoring-portal.org/wbb/index.php?page=Thread&threadID=28099