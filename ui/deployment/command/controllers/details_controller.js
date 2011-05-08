/**
 * @tag command
 * @test command/funcunit.html
 * Renders the clusters details: cluster status & stats, node status & stats.
 */	
$.Controller.extend("Command.Controllers.Details",{
	listensTo: ["show", "hide", "refresh"]
},
{
	init : function(el, options){
		this.fw_mark = options.fw_mark;
		this.datacenterUIState = {};
		this.isFirstPass = true;		
		this.element.hide();		
	},
	
    /**
     * Listens to Command.Models.Status load balancer data updates and 
     * does two things:
     * <ul>
     * <li>Sets the cluster background color/status.</li>
     * <li>Calls refresh to update cluster, node status and stats.</li>
     * </ul>
     * @param {String} called The called function name.
     * @param {Object} data Load balancer status data.
     */	
	"statuses.updated subscribe": function(called, data) {
        var s = Command.Models.Status.findByFwMark( this.fw_mark ),
			weight = Command.Models.Status.findClusterWeightByFwMark( this.fw_mark );
			
        for (var datacenter in s) {
            // save datacenter status in Command.Models.Status.statusStore
            // this is used to change datacenter background color
			// and by filters like 'clusters down' to filter clusters by status
			var downPageColor = Command.Controllers.Main.defaults.DOWNPAGE_COLOR;
            s[datacenter]["status"] = weight == -1 ? downPageColor : Command.View.Helpers.clusterStatusGradient(s[datacenter]);
        }
		
		if (this.element.is(":visible")) {			
			this.refresh();
		}
	},	
	
	refresh: function() {		
			var clusterEl = this.element.closest(".cluster"),
				cluster = clusterEl.model().merge(),
				statuses = Command.Models.Status.findByFwMark( cluster.fw_mark );
			
			this.element.html(this.view('details', {
				cluster: cluster,
				statuses: statuses,
				datacenterUIState: this.datacenterUIState
			}, Command.View.Helpers));
			
			// collapse datacenter ui if number of nodes higher than 10
			// and it wasn't manually expanded by the user
			var numberOfNodes = this.getNumberOfNodes( statuses );			
			if ( numberOfNodes >= 10 ) {
				for ( var datacenter in statuses ) {
					var dcEl = this.find("." + datacenter + ":first");
					if ( !dcEl.hasClass("expanded") || this.isFirstPass ) {
						this.find("." + datacenter + "_row").hide();
						dcEl.addClass("collapsed");
						dcEl.find(".ui-icon").removeClass("ui-icon-triangle-1-s").addClass("ui-icon-triangle-1-e");
						this.datacenterUIState[datacenter] = "collapsed";
					}			
				}
			}
			
			this._updateDatacenterStatus( statuses );
			
			// update node statuses							
			var self = this;
			for (var datacenter in statuses) {
				$.each(statuses[datacenter], function(ip, status){
					if( $.inArray( ip, [ "config", "totals", "status"] ) == -1 ) { // if it's an ip
						self._updateNodeStatus(clusterEl, datacenter, ip, status);
					}
				});
			}

			this.isFirstPass = false;
	},
	
	getNumberOfNodes: function( statuses ){
		var self = this, numberOfNodes = 0;
		for (var datacenter in statuses) {
			$.each(statuses[datacenter], function(ip, status){
				if ($.inArray(ip, ["config", "totals", "status"]) == -1) { // if it's an ip
					numberOfNodes += 1;
				}
			});
		}
		return numberOfNodes;	
	},
	
	show: function(el, ev) {
		this.element.show();
		this.refresh();
	},
	
	hide: function(el, ev) {
		this.element.hide();
	},
	
	".config click": function(el, ev) {
		var clusterEl = this.element.closest( ".cluster" ),
			cluster = clusterEl.model(),
			statuses = Command.Models.Status.findByFwMark( cluster.fw_mark ),
			scrollTop = $("#clusters").scrollTop();
			
		for (var datacenter in statuses) {
			if ( el.hasClass( datacenter ) ) {
				this.find("." + datacenter + "_row").toggle();
				if( el.hasClass("collapsed") ) {
					el.removeClass("collapsed");
					el.find(".ui-icon").removeClass("ui-icon-triangle-1-e")
									   .addClass("ui-icon-triangle-1-s");					
					this.datacenterUIState[datacenter] = "expanded";
				} else {
					el.addClass("collapsed");
					el.find(".ui-icon").removeClass("ui-icon-triangle-1-s")
									   .addClass("ui-icon-triangle-1-e");
					this.datacenterUIState[datacenter] = "collapsed";					
				}				
			}
		}						
		$("#clusters").scrollTop( scrollTop );
	},
	
	_updateDatacenterStatus: function( statuses ) {
		for ( var datacenter in statuses ) {
			this.find("." + datacenter + ":first")
			  .css( 'backgroundColor', statuses[datacenter]["status"] );
		}			
	},
	
	_updateNodeStatus: function(clusterEl, datacenter, ip, status) {
		var tr, isDownpage = false;
		if( /^127\.\d+\.\d+\.1:\d+$/.test( ip ) ) {
			var id = ["dp", "-", datacenter, "-", this._makeSelector(ip)].join('');
			tr = $("#" + id);
			if ( !tr.length ) {
				tr = this.view("downpage", {
					id: id,
					datacenter: datacenter,
					s: status
				}, Command.View.Helpers);
				
				clusterEl.find("tr." + datacenter + "_row:last").after( tr );
				
				// hide if datacenter is collapsed
				var dcEl = this.find("." + datacenter + ":first");
				if ( dcEl.hasClass("collapsed") ) {
					$("#" + id).hide();
				}
								
				$("#" + id).css('background', 'blue');
			}
		}
		else {
			tr = ["#", datacenter, "-", this._makeSelector(ip)].join('');
			var tr = $( tr );
			tr.removeClass("nodata");
			tr.css('background', Command.View.Helpers.nodeStatusColor(status[1], status[2], status[3]));
			tr.find("td.status a").mxui_tooltip( {
					width: "320px",
					keep: true
				} );   				
		}		
	},
	
	"td.status a click": function( el, ev ) {
		ev.preventDefault();
		var href = el.attr("href");
		el.trigger( "open:tooltip",
		 this.view( "//command/views/main/node_status.ejs", { href: href }) );				
	},
	
	_makeSelector: function( ip ) {
        return ip.split('.').join('-').replace(':','-');
    }
})