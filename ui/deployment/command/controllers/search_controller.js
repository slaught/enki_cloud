/**
 * Searches when appropriate
 */
$.Controller.extend("Command.Controllers.Search",{
	defaults : {
		text: "Search service by name: AU SMTP"
	}
},{
	init : function(){
		if(!this.element.val()){
			this.element.val(this.options.text)
		}
		
		if(this.element.val() == this.options.text){
			this.element.addClass("default")
		}else{
			//this.search();
		}
	},
	
	"focusin" : function(){
		if(this.element.val() == this.options.text){
			this.element.val("").removeClass("default")
		}else{
			this.element[0].select();
		}
	},
	focusout : function(){
		if(this.element.val() == ""){
			this.element.val(this.options.text).addClass("default")
		}
	},
	//listen to keypress and issue a search after a few seconds
	"keypress" : function(){
		clearTimeout(this.searchTimeout)
		this.searchTimeout = setTimeout(this.callback('search', null), 200)
	},
	search : function(term){
		if(term != null){
			this.element.val(term).removeClass("default")
		}
		var val = this.element.val();
		this.element.trigger('search', val == this.options.text ? "" : val);
	},
	val : function(newVal){
		if(newVal){
			this.element.val(newVal).removeClass("default");
			
		}else{
			var val = this.element.val();
			return val == this.options.text ? "" : val;
		}
		
	}
})