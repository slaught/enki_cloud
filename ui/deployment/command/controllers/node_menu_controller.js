/**
 * Node Menu Controller
 */
$.Controller.extend("Command.Controllers.NodeMenu",{
	start : function(){
		//make node menu element for everyone
		this.nodeMenuEl = $("<div class='node_menu'></div>")
			.css("zIndex",9998)
			.hide()
			.appendTo( $("#clusters") )
			.mxui_positionable( {
				my: 'left top',
				at: 'left bottom',
				offset: '0 0',
				collision: 'none none',
				keep : true
			});
			
		$(document.body).click(function(){
			Command.Controllers.NodeMenu.nodeMenuEl.fadeOut("fast")
		})
	},
	
	defaults: {
		fontSize: "0.7em",
		width: "auto",
		height: "auto",
		padding: "15px",
		backgroundColor: "#FFFFFF",
		border: "2px solid #000000"
	}
},
{
	init: function() {
		this.node = this.options.node;
	},
	
	click: function(el, ev) {
		ev.stopPropagation();
		
		this.Class.nodeMenuEl.html(this.view("node_links", {
			node: this.node
		})).hide().css({
			border: this.options.border,
			backgroundColor: this.options.backgroundColor,
			padding: this.options.padding,
			width: this.options.width,
			height: this.options.height,
			fontSize: this.options.fontSize
		}).trigger("move", this.element).fadeIn("fast");
				
	}
})