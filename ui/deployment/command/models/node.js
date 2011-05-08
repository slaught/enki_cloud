$.Model.extend("Command.Models.Node",{
	findOne : function(id, params, success) {
		var rnd = Math.floor(Math.random() * 100000);
		$.get(id + "?callback=?", {},
			 this.callback(success), 'json',
			 "//command/fixtures/node1.json?" + rnd);			
	}
},{

})