$.Model.extend("Command.Models.Cluster",{
	//storeType: jQuery.Model.Store,
	id: "fw_mark",
	findAll : function(params, success){
		$.get("/clusters.json",{}, this.callback(['wrapMany','setupLoadBalancers',success]),'json',
			"//command/fixtures/clusters.json")
	},
	setupLoadBalancers : function(clusters){
		Command.loadBalancers = clusters[0].load_balancers;
		//get a list of hosts
		var hosts = [];
        for (var lb in Command.loadBalancers) {
            hosts.push(lb);
        }
        Command.Models.Status.hosts = hosts;
		return $.makeArray(arguments);
	}
},{
	getDetails: function(success){
		// this.link is the correct URL for this information
		$.get(this.link + "?callback=?", {},
			 this.callback(success), 'json',
			 "//command/fixtures/clusterDetails.json");	
	},
	/**
	 * @returns a list of ips by callcenter {abc: [10.8], efg: [10.2]}
	 */
	getIPsByDataCenter : function(){
		if(!this._ipsByDataCenter){
			this._ipsByDataCenter = {};
			for ( var n = 0; n < this.nodes.length; n++ ) {
				var node = this.nodes[n];
				if ( !this._ipsByDataCenter[node.datacenter_name] ) {
					this._ipsByDataCenter[node.datacenter_name] = [];
				}
				this._ipsByDataCenter[node.datacenter_name].push( node.ip_address );
			}
		}
		return this._ipsByDataCenter
	},
	//adds 'missing' nodes into this cluster (service).
	merge : function(){
		// re-org ips for easier checking
		var clusterIPs = this.getIPsByDataCenter(),
			//get current statuses from loadbalancers for this service
			statuses = Command.Models.Status.findByFwMark(this.fw_mark);
			
		
		
		// go through the statuses list and check if
		// each IP has a match in the clusterIPs list:
		// if it doesn't add an entry for it in cluster.nodes
		for (var datacenter in statuses ) {
			for( var ip in statuses[datacenter] ) {
				
				if ( $.inArray( ip, [ "config", "totals", "status"] ) == -1 && //if it is an ip address
					$.inArray( ip, clusterIPs[datacenter] ) == -1 && //and it's not in clusterIP
					!/^127\.\d+\.\d+\.1:\d+$/.test( ip ) ) { // and it's not downpage node
					
					this.nodes.push( {
				      "datacenter_name" : datacenter,
				      "ip_address" : ip,
					  "mssing_from_clusters_json": true
					} );
					//invalidate the cache
					this._ipsByDataCenter = null;
				}
			}
		}
		return this;
	}
})
