Command.View = {
	Helpers : {
		// calculates status for service (includes all datacenters)
		serviceStatusGradient: function( statuses ) {
			var ups = 0, 
				total = 0;
			for (var datacenter in statuses) {
				for (var ip in statuses[datacenter]) {
					if ($.inArray(ip, ["config", "totals", "status"]) == -1) { // if it's an ip
						var n = statuses[datacenter][ip];
						var nodeStatus = this.nodeStatus(n[1], n[2], n[2]);
						if ($.inArray( nodeStatus, ["active", "idle", "idle wait"]) != -1) { // if node is up
						   	ups += 1;
						}
						total += 1;
					}
				}
			}
			
			var ratio = ups/total;
			return this.calculateStatusBgColorByNodeRatio( ratio );
		},
		// calculates status for a cluster (only for one datacenter)
		clusterStatusGradient: function( status ) {
			var ups = 0, 
				total = 0;
			for(var ip in status) {
				if ($.inArray(ip, ["config", "totals", "status"]) == -1) { // if it's an ip
				   	var n = status[ip];
				   	var nodeStatus = this.nodeStatus( n[1], n[2], n[2] );
					if ($.inArray( nodeStatus, ["active", "idle", "idle wait"]) != -1) { // if node is up
					   	ups += 1;
					}
					total += 1;
				 }
			}
			var ratio = ups/total;
			return this.calculateStatusBgColorByNodeRatio( ratio );										


		},
		calculateStatusBgColorByNodeRatio: function( ratio ) {
			var color = "gray";
			if (ratio > 0.8 && ratio <= 1) {
				color = "#79E851";
			} else if (ratio > 0.70 && ratio <= 0.8) {
				color = "#CFE851"				
			} else if (ratio > 0.6 && ratio <= 0.7) {
				color = "#E8E551";
			} else if (ratio > 0.5 && ratio <= 0.6) {
				color = "#FAFA69";
			} else if (ratio > 0.4 && ratio <= 0.5) {
				color = "#FAE969";
			} else if (ratio > 0.3 && ratio <= 0.4) {
				color = "#FAE469";
			} else if (ratio > 0.2 && ratio <= 0.3) {
				color = "#FAC569";
			} else if (ratio > 0.1 && ratio <= 0.2) {
				color = "#FAA569";
			} else if (ratio > 0.05 && ratio <= 0.1) {
				color = "#FA9969";
			} else if (ratio >= 0 && ratio <= 0.05) {
				color = "red";
			}		
			return color;			
		},
		clusterStatus : function(w) {
		    if (w< 0 ) {
		      return "blue";
		    } else if (w== 0 || w == 1 ) {
		      return "red";
		    } else if (w> 1 && w<100 ) {
		      return "yellow"; 
		    } else if (w >= 100 ) {
		      return "green";
		    }
		},		
		
		clusterStatusColor : function(w) {
		    if (w< 0 ) {
		      return "steelblue"; // .downpage {  background: steelblue ; }
		    } else if (w== 0 || w == 1 ) {
		      return "#ff3d00"; // .red {  background: #ff3d00; }
		    } else if (w> 1 && w<100 ) {
		      return "yellow"; 
		    } else if (w >= 100 ) {
		      return "limegreen"; // "#00ff00"; //.up{ background: green ; }
		    }
		},
		
		schedLabel: function(s) {
			  var l = '';
			  switch(s) {
			    case "rr":
			       l = "Round Robin";
			       break;
			    case "wlc":
			      l = "Weighted Least-Connection";
			      break;
			    case "wrr":
			      l = "Weighted Round Robin";
			      break;
			    default: 
			      l = s;
			  }
			  return l;			
		},
		
		nodeStatus: function(weight, activeconn, inactiveconn){
			if (weight == 0) {
				return "down";
			}
			else if (activeconn > 0) {
				return "active";
			}
			else if (inactiveconn > 0) {
				return "idle wait";
			}
			else if (activeconn == 0) {
				return "idle";
			}else {
				return "offline";
			}
		},
		nodeStatusFromStatuses : function(node, statuses){
			var status = statuses[node.datacenter_name] &&
        				 statuses[node.datacenter_name][node.ip_address] && 
						 statuses[node.datacenter_name][node.ip_address];
			 return status ? 
			 	this.nodeStatus(status[1], status[2], status[3]) :
			 	"no data";
		},
		nodeStatusColor: function( weight, activeconn, inactiveconn )	{
		   var g = "green";
		   var x = "gray";
		   var down = "red";
		   if ( weight == 0 ) {
		      return down;
		   } else if ( activeconn >= 0 || inactiveconn > 0 ) {
		      return g;
		   } else if ( activeconn > 0 ) {
		      return g;
		   } else if ( inactiveconn > 0 ) {
		      return g;
		   } else if ( activeconn ==  0 ) {
		      return g;
		   } else {
		      return x;
		   }
		},
		
		getClusterTotals: function(status, idx) {
			var total = 0;
			for(var ip in status) {
				if( $.inArray( ip, [ "config", "totals", "status"] ) == -1 ) { // if it's an ip
					total += status[ip][idx];
				}
			}
			return total;
		},
		
		getServiceTotals: function(statuses, idx) {
			var total = 0;
			for (var datacenter in statuses) {
				for (var ip in statuses[datacenter]) {
					if( $.inArray( ip, [ "config", "totals", "status"] ) == -1 ) { // if it's an ip
						total += statuses[datacenter][ip][idx];
					}
				}
			}
			return total;
		},
		
		formatValue : function( value, engineeringNotation ) {
			var text = value.toString();
			var integerPart = text;
			
			// add thousands separator
			var parts = "",
				part = "",
				engineeringParts = [],
				groupSize = 3, j = 1, firstPass = true;
			var length = integerPart.length;
			if (length > groupSize) {
				for (var i = length - 1; i >= 0; i--) {
					part = integerPart.charAt(i) + part;
					if (j == 3) {
						parts = firstPass ? part : part + "," + parts;
						engineeringParts.push( part );
						part = "";
						firstPass = false;
						j = 0;
					}
					j++;
				}
			}
			if( part != "") {
				parts = part + "," + parts;
				engineeringParts.push( part );
			}
			//parts = part != "" ? part + "," + parts : parts;
			integerPart = parts != "" ? parts : integerPart;
			
			// format with engineering notation
			if( engineeringNotation ) {
				var result,
					l = engineeringParts.length;
				if ( l == 6 ) {
					result = [ engineeringParts[5], ".", engineeringParts[4], "P" ].join("");
				} else if ( l == 5 ) {
					result = [ engineeringParts[4], ".",  engineeringParts[3], "T" ].join("");
				} else if ( l == 4 ) {
					result = [ engineeringParts[3], ".", engineeringParts[2], "G" ].join("");
				} else if ( l == 3 ) {
					result = [ engineeringParts[2], ".", engineeringParts[1], "M" ].join("");
				} else if ( l == 2 ) {
					result = [ engineeringParts[1], ".", engineeringParts[0], "K" ].join("");
				} else if ( l == 1 ) { 
					result = [ engineeringParts[0], "B" ].join("");
				} else {
					result = integerPart;
				}    
				return result;
			}
				
			return integerPart;
		}								

		
	}
}