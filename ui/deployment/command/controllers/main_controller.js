$.Controller.extend("Command.Controllers.Main", {
    onDocument: true,
    defaults: {
        REFRESH_PERIOD: 10,
        DOWNPAGE_COLOR: '#51D9E8'
    },
    listensTo: ["search"]
}, {
    init: function(){
        this.searches["DOWNPAGE_COLOR"] = this.options.DOWNPAGE_COLOR;
    },
    ready: function(){
        //get cluster data
		Command.Models.Cluster.findAll({}, this.callback('list'));
		$("#clusters").mxui_filler({parent: document.body})
		$("#search .search").command_search();
    },
    
    list: function(clusters){
        // render service headers
        $("#clusters").html(this.view(clusters));
        Command.Controllers.NodeMenu.start();
        
        $("#loadBalancers").command_load_balancers();
        Command.Models.Status.findOne(Command.Models.Status.hosts.length, {}, 
			this.callback('updateClusterStatus', Command.Models.Status.hosts.length - 1),
			this.callback('callNext', Command.Models.Status.hosts.length - 1));
    },
    callNext : function(count){
		Command.Models.Status.findOne(count, {}, this.callback('updateClusterStatus', count - 1),
				this.callback('callNext', count - 1))
	},
	//updates the clusters
    updateClusterStatus: function(count, data){
        this._refreshFilters();
        if (count != 0) {
            this.callNext(count)
        }
        else {
            this.startBackgroundRefreshing();
			this.publish('statuses.updated', {
				 period: this._period()
			});
        }
    },
	"statuses.updated subscribe": function(called, params) {
		var self = this,
		    clusterTypeServiceEls = this.find(".cluster_type_service"),
			portfwdTypeServiceEls = this.find(".portfwd_type_service");
		
		// update cluster services background color		
		$.each( clusterTypeServiceEls, function( idx, el ) {
			el = $(el);
			var cluster = el.model(),
				fw_mark = cluster.fw_mark,
				statuses = Command.Models.Status.findByFwMark(  fw_mark ),
				weight = Command.Models.Status.findClusterWeightByFwMark( fw_mark );
				
            var serviceBgColor = weight == -1 ? self.options.DOWNPAGE_COLOR : Command.View.Helpers.serviceStatusGradient( statuses );			
			setTimeout( function() {
				// update service header background color to match current status
	            el.css( 'backgroundColor', serviceBgColor );				
				// update service header node icons
	            self.updateNodeIconsColors( el );
			}, Math.floor( Math.random()*500 ) );		
		});
		
		// update port forwards services background color
		$.each( portfwdTypeServiceEls, function( idx, el ) {
			el = $(el);
			var cluster = el.model(),
				fw_mark = cluster.fw_mark,
				statuses = Command.Models.Status.findByFwMark(  fw_mark ),
				serviceBgColor = "yellow",
				s;			
			
			// get status for this service only node	
			for ( var datacenter in statuses ) {
				for (var ip in statuses[datacenter]) {
					if ($.inArray(ip, ["config", "totals", "status"]) == -1) { // if it's an ip
						s = statuses[datacenter][ip];
					}
				}
			}	
			
			// service color is green if node is green else yellow
			if (s) {
				serviceBgColor = Command.View.Helpers.nodeStatusColor(s[1], s[2], s[3]);
				serviceBgColor = serviceBgColor == "green" ? "#79E851" : "yellow";
			}
									
			setTimeout( function() {
				// update service header background color to match current status
	            el.css( 'backgroundColor', serviceBgColor );				
			}, Math.floor( Math.random()*500 ));									
			
		});		
	},
	_period : function(){
		var period = $("input[name=refresh_period]").val();
        period = parseInt(period) * 1000;
        period = isNaN(period) ? this.options.REFRESH_PERIOD * 1000 : period;
		return period;
	},
    startBackgroundRefreshing: function(timeout){
        var period =this._period()
        period = timeout ? timeout : period;
        this.refreshTimeout = setTimeout(this.callback("refreshStatus"), period);
    },
    refreshStatus: function(){
        Command.Models.Status.findOne(Command.Models.Status.hosts.length, {}, 
		this.callback('updateClusterStatus', Command.Models.Status.hosts.length - 1));
    },
    "input[name=refresh_period] keydown": function(el, ev){
        var self = this;
        if (this.typingTimeout) {
            clearTimeout(this.typingTimeout);
        }
        this.typingTimeout = setTimeout(function(){
            clearTimeout(self.refreshTimeout);
            self.startBackgroundRefreshing(1);
        }, 3000);
    },
	// this is a round-about way to call search :(
    _refreshFilters: function(){
        this.runSearch( $("#search .search").controller("search").val() );
    },
    updateNodeIconsColors: function( clusterEl ){
        var greens = [], 
			grays = [], 
			reds = [],
			cluster = clusterEl.model().merge(),
			statuses = Command.Models.Status.findByFwMark( cluster.fw_mark ),
			status,
			node;
        
        
        for (var n = 0; n < cluster.nodes.length; n++) {
            node = cluster.nodes[n]
			status = Command.View.Helpers.nodeStatusFromStatuses( node, statuses );
			if (status == "down") {
                reds.push(node);
            }
            else if ($.inArray(status, ["active", "idle", "idle wait"]) != -1) {
                greens.push(node);
            }
            else {
                grays.push(node);
            }
        }
        
        var nodeIconsEl = clusterEl.children(".node_icons");
        clusterEl.find(".node_icons").html(this.view("node_icons", {
            greens: greens,
            grays: grays,
            reds: reds
        }));
        
        
        var self = this;
        nodeIconsEl.children(".node_icon").each(function(idx, iconEl){
            $(iconEl).mxui_tooltip({
                renderCallback: self.callback("_renderNodeTooltip"),
                width: "320px"
            });
        });
    },
    _renderNodeTooltip: function(el, ev, callback){
        var href = el.find("a").attr("href");
		callback( this.view( "//command/views/main/node_status.ejs", { href: href }) );		
    },
    toggleRow: function(clusterEl){
        var expanderEl = clusterEl.find(".expand")
        if (expanderEl.hasClass("expanded")) {
            clusterEl.children('.details').trigger("hide");
            expanderEl.removeClass("expanded ui-icon ui-icon-triangle-1-s");
            expanderEl.addClass("ui-icon ui-icon-triangle-1-e");
        }
        else {
            clusterEl.children('.details').trigger("show");
            expanderEl.removeClass("ui-icon ui-icon-triangle-1-e");
            expanderEl.addClass("expanded ui-icon ui-icon-triangle-1-s");
        }
    },
    ".expand click": function(el, ev){
        var clusterEl = el.closest('.cluster')
        this.toggleRow(clusterEl);
        ev.stopImmediatePropagation();//this.stopImmediatePropagation
    },
    ".cluster h3.cluster_name click": function(el, ev){
        this.toggleRow(el.closest('.cluster'));
    },
    ".cluster a.cluster_status click": function(el, ev){
        ev.stopPropagation();
    },
	
	"#search .help_button click": function(el, ev) {
		$("#help").slideToggle("fast", function(){
			$(window).trigger('resize')
		});
	},
    // listens for search terms
    search: function(el, ev, searchTerm){
        window.location = "#&search="+searchTerm
		this.runSearch(searchTerm);
    },
	"history.** subscribe" : function(called, params){
		this.runSearch(params.search || "");
		$("#search .search").controller("search").val(params.search || "")
	},
	runSearch : function(searchTerm){
		for (var term in this.searches) {
            if (searchTerm == term) {
                this.searches[term]();
				// save this search
                return;
            }
            else 
                if (term) {
                    var parts = searchTerm.match(new RegExp(term));
                    if (parts) {
                        this.searches[term](parts);
                        return;
                    }
                }
        }
        this.searches["service.name.(.+)"](["search name " + searchTerm, searchTerm])
	},
    searches: {
        //show all
        "": function(){
            $(".cluster").show();
        },
        "ALL": function(){
            $(".cluster").show();
        },
        "down clusters": function(){
            // down cluster without down page node active
            this["cluster.status.(\w+)"](["cluster.status.red", 'red', this.DOWNPAGE_COLOR]);
        },
        "down nodes": function(){
            this["node.status.(\w+)"](["node.status.down", 'down'])
        },
        "cluster.status.(\w+)": function(parts){
            var self = this;
            $(".cluster").each(function(idx, clusterEl){
                clusterEl = $(clusterEl);
                var found = false;
                // if it's not a cluster then bypass (we just have status algorithm for clusters)
                if (clusterEl.attr("id").indexOf("command_models_cluster_") != -1) {
                    var cluster = clusterEl.model();
                    var statuses = Command.Models.Status.findByFwMark(cluster.fw_mark);
                    for (var datacenter in statuses) {
                        if (statuses[datacenter].status.indexOf(parts[1]) != -1 ||
                        statuses[datacenter].status.indexOf(parts[2]) != -1) {
                            clusterEl.show();
                            found = true;
                        }
                    }
                }
                if (!found) {
                    clusterEl.hide();
                }
            });
        },
        "node.status.(\w+)": function(parts){
            var self = this;
            $(".cluster").each(function(idx, clusterEl){
                clusterEl = $(clusterEl);
                var cluster = clusterEl.model(), statuses = Command.Models.Status.findByFwMark(cluster.fw_mark), found = false;
                for (var datacenter in statuses) {
                    for (var ip in statuses[datacenter]) {
                        if (ip != "totals" &&
                        ip != "config" &&
                        ip != "status") {
                            var s = statuses[datacenter][ip];
                            var label = Command.View.Helpers.nodeStatus(s[1], s[2], s[3]);
                            if (label.indexOf(parts[1]) != -1) {
                                clusterEl.show();
                                found = true;
                            }
                        }
                    }
                }
                if (!found) {
                    clusterEl.hide();
                }
            });
        },
        "^\\d+\\.?(\\d+)?\\.?(\\d+)?\\.?(\\d+)?\\:?(\\d+)?$": function(parts){
            $(".cluster").each(function(idx, clusterEl){
                clusterEl = $(clusterEl);
                var cluster = clusterEl.model(), 
					found = false;
                for (var n = 0; n < cluster.nodes.length; n++) {
                    var node = cluster.nodes[n];
                    if ( node.ip_address && 
						 node.ip_address.indexOf(parts[0]) != -1 ||
						 node.status_url && 
						 node.status_url.indexOf(parts[0]) != -1 ) {
                        	clusterEl.show();
                        	found = true;
                    }
                }
                if (!found) {
                    clusterEl.hide();
                }
            });
        },
        "service.name.(.+)": function(parts){
            $(".cluster").each(function(idx, clusterEl){
                clusterEl = $(clusterEl);
                var cluster = clusterEl.model();
                if (cluster.description.indexOf(parts[1]) != -1) {
                    clusterEl.show();
                }
                else {
                    clusterEl.hide();
                }
            });
        },
        "node\\s(.+)": function(parts){
            var self = this;
            $(".cluster").each(function(idx, clusterEl){
                clusterEl = $(clusterEl);
                var cluster = clusterEl.model(), found = false;
                for (var n = 0; n < cluster.nodes.length; n++) {
                    var node = cluster.nodes[n];
                    if (node.hostname && 
						node.hostname.indexOf(parts[1]) != -1) {
                        clusterEl.show();
                        found = true;
                    }
                }
                if (!found) {
                    clusterEl.hide();
                }
            });
        }
    },
    "#search .show_all click": function(el, ev){
        $("#search .search").command_search("search", "ALL")
    },
    
    "#search .down_clusters_filter click": function(el, ev){
        $("#search .search").command_search("search", "down clusters")
    },
    
    "#search .down_nodes_filter click": function(el, ev){
        $("#search .search").command_search("search", "down nodes")
    }
    
})
