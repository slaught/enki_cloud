$.Controller.extend("Command.Controllers.LoadBalancers",{
	init : function(){
		this.element.html(this.view());
		this.timestamps = [];
		this.statuses = [];
	},
	"status.update subscribe" : function(called, data){
		//get time
		for(var i =0; i < Command.Models.Status.hosts.length; i++){
			if(Command.Models.Status.hosts[i] == data.host){
				break;
			}
		}
		var el = this.element.find(".loadbalancer")[i]
		
		
		
		if(!this.timestamps[i]){
			this.timestamps[i] = {
				timeStamp: data.time,
				pulledAt: new Date(),
				count: 0
			}
			
			el.className = "loadbalancer up_node node_icon";
		}else{
			//check if the timestamp is really old
			if(data.time == this.timestamps[i].timeStamp){
				this.timestamps[i].count ++;
				this.timestamps[i].pulledAt = new Date
			}else{
				this.timestamps[i] = {
					timeStamp: data.time,
					pulledAt: new Date(),
					count: 0
				}
			}
		}
	},
	"statuses.updated subscribe" : function( called, params ){
		setTimeout(this.callback( 'updateStamps', params.period ),100)
	},
	updateStamps : function(interval){
		var timestamp,
			now = new Date,
			lbs = this.element.find(".loadbalancer");
		this.statuses = [];
		for(var i in this.timestamps){
			timestamp = this.timestamps[i];
			if(!timestamp){
				lbs[i].className = "loadbalancer down_node node_icon";
				this.statuses.push( "down" );
			}if(now - timestamp.pulledAt > 20 * interval){
				lbs[i].className = "loadbalancer down_node node_icon"
				this.statuses.push( "down" );
			}else if(timestamp.count > 4){
				lbs[i].className = "loadbalancer offline_node node_icon"
				this.statuses.push( "offline" );
			}else{
				lbs[i].className = "loadbalancer up_node node_icon"
				this.statuses.push( "up" );
			}
		}
		
		// update load balancer status details if slide panel is visible
		var lbsDetailsEl = $("#loadBalancerDetails"); 
		if ( lbsDetailsEl.is( ":visible" ) ) {
			lbsDetailsEl.html( this.view( "slide_panel", {
				statuses: this.statuses
			} ) );						
		}
	},
	//on click, toggle the loadbalancer list
	click : function() {
 		var self = this;				
		$("#loadBalancerDetails").slideToggle("fast",function(){
			$(this).html( self.view( "slide_panel", {
				statuses: self.statuses
			} ) );			
			$(window).trigger('resize')
		})
	}
})