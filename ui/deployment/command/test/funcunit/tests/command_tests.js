module("command/command test",{ 
	setup: function(){
        S.open("//command/command.html");
		S("#command").exists();
		S("input[name=refresh_period]").type("[backspace][backspace]9999");
	}
})

test("Command App Structure Test", function(){
    
	S("#search").exists();
	S("#help").exists();
	S("#loadBalancerDetails").exists();
	S("#clusters").exists();
	
} );

test("Command App Structure Test", function(){
    
	S("#search .command_search").exists();
	S("#search .show_all").exists();
	S("#search .show_all").click();
	S("#clusters .cluster:eq(0)").exists( function() {
		var summary = S("#clusters .cluster:eq(0)").attr( "summary" );
		ok( /aea_frontend/.test( summary ), "First row is AEA Frontend." );
	} );
	S("#clusters .cluster:eq(1)").exists( function() {
		var summary = S("#clusters .cluster:eq(1)").attr( "summary" );
		ok( /aea_ivr/.test( summary ), "First row is AEA Ivr." );
	} );
	S("#clusters .cluster:eq(2)").exists( function() {
		var summary = S("#clusters .cluster:eq(2)").attr( "summary" );
		ok( /aea_portal/.test( summary ), "First row is AEA Portal." );
	} );			

	
} );

test("Cluster Details Test", function(){
	
	S("#search .command_search").exists();
	S("#search .show_all").exists();
	S("#search .show_all").click();
	S("#clusters .cluster:eq(0)").exists( function() {
		var tr = S("#clusters .cluster:visible:eq(0)");
		var summary = tr.attr( "summary" );
		ok( /aea_frontend/.test( summary ), "First row is AEA Frontend." );
		//ok( /rgb(121, 232, 81)/.test( tr.css("backgroundColor") ), "AEA Frontend background color is #79E851." )
	} );
	    
	S("#clusters .cluster:eq(0) h3.cluster_name").exists();		
	S("#clusters .cluster:eq(0) h3.cluster_name").click();
	S("#clusters .cluster:eq(0) .command_details").visible();
	S("#clusters .cluster:eq(0) .command_details table").visible( function() {
		var serviceTitle = S("#clusters .cluster:eq(0) .command_details table td.service_title"); 
		ok( /AEA Frontend/.test( serviceTitle.html() ), "AEA Frontend cluster details open." )
	} );
	
} );

test("Down Clusters Test", function(){
	
	S("#search .command_search").exists();
	S("#search .down_clusters_filter").exists();
	S("#search .down_clusters_filter").click();
	S("#clusters .cluster:visible:eq(0)").exists( function() {
		var tr = S("#clusters .cluster:visible:eq(0)");
		var summary = tr.attr( "summary" );
		ok( /isen_frontend/.test( summary ), "First row is Isengard frontend." );
		//ok( /rgb(81, 217, 232)/.test( tr.css("backgroundColor") ), "Isengard frontend background color is #51D9E8." )		
	} );
	    
	S("#clusters .cluster:visible:eq(0) h3.cluster_name").click();
	S("#clusters .cluster:visible:eq(0) .command_details").visible();
	S("#clusters .cluster:visible:eq(0) .command_details table").visible( function() {
		var serviceTitle = S("#clusters .cluster:visible:eq(0) .command_details table td.service_title"); 
		ok( /Isengard frontend/.test( serviceTitle.html() ), "Isengard frontend cluster details open." )		
	} );
	
} );

test("Down Nodes Test", function(){
	
	S("#search .command_search").exists();
	S("#search .down_nodes_filter").exists();
	S("#search .down_nodes_filter").click();
	S("#clusters .cluster:visible:eq(0)").exists( function() {
		var tr = S("#clusters .cluster:visible:eq(0)");
		var summary = tr.attr( "summary" );
		ok( /aea_portal/.test( summary ), "First row is AEA Portal." );
		//ok( /rgb(207, 232, 81)/.test( tr.css("backgroundColor") ), "AEA Portal background color is #CFE851." )		
	} );
	    
	S("#clusters .cluster:visible:eq(0) h3.cluster_name").click();
	S("#clusters .cluster:visible:eq(0) .command_details").visible();
	S("#clusters .cluster:visible:eq(0) .command_details table").visible( function() {
		var serviceTitle = S("#clusters .cluster:visible:eq(0) .command_details table td.service_title"); 
		ok( /AEA Portal/.test( serviceTitle.html() ), "AEA Portal cluster details open." ); 
	} );
	
} );