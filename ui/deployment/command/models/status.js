$.Model.extend("Command.Models.Status",{
	id: "host",
	hosts: [],
       findOne : function(id, params, success, error) {
           var rnd = Math.floor(Math.random() * 100000);
		 var fix = false ? "http://google.com" : "//command/fixtures/load" + id + "status.json?" + rnd
           $.ajax({
                   url: 'http://' + this.hosts[id-1] + "/lvs.json?callback=?",
                   jsonpCallback: "lvs",
                   success: this.callback(['saveData', success]),
				   error: error,
                   dataType: 'jsonp',
                   data: {},
				   timeout: 4000,
                   fixture: fix
           });
       },
	statusStore : {},
	saveData : function( json ){
		this.statusStore[json.host] = json;
		this.publish("update", json)
		return [json]
	},
	
	//goes through each loadbalancer's data and sees if this services has data
	//results come organized by loadbalancer.
	findByFwMark : function(fw){
		fw = ""+fw;
		var result = {};
		for(var name in this.statusStore){
			if(this.statusStore[name][fw]){
				// for each datacenter get the cluster status
				var datacenter = Command.loadBalancers[name];
				if (!result[datacenter]) {
					result[datacenter] = this.statusStore[name][fw];
				}
			}
		}
		return result;
	},
	findClusterWeightByFwMark: function( fwd ) {
		for (var host in this.statusStore) {
			var globalStatus = this.statusStore[host].status;
			for (var i = 0; i < globalStatus.length; i++) {
				var s = globalStatus[i];
				if (s[0] == fwd) {
					return s[1];
				}
			}
		}
	}
},{

})