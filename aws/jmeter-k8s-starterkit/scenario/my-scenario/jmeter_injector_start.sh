cd //opt/jmeter/apache-jmeter/bin
sh PluginsManagerCMD.sh install-for-jmx my-scenario.jmx > plugins-install.out 2> plugins-install.err
jmeter-server -Dserver.rmi.localport=50000 -Dserver_port=1099 -Jserver.rmi.ssl.disable=true >> jmeter-injector.out 2>> jmeter-injector.err &
trap 'kill -10 1' EXIT INT TERM
java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-injector.out 2>> jmeter-injector.err
wait
