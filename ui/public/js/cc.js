//
// comand control
//
//
function toggleiframe(id) {
  $(id).toggle('blind',{}, 500); 
  return false;
}
function remove_request(host) {
  if ( window.lvs_request[host] ) {
    window.lvs_request[host].removeScriptTag() ;
  } 
}
function lvs(data) 
{
  var host = data.host;
  window.lvs_data[host] = data;
  remove_request(host);
  set_timestamp(data);
  process1(data);
}
function set_timestamp(lvs_json_data) {
    var d = new Date(lvs_json_data.time * 1000);
    $('#timestamp').text( d.toString() );
}

function mylog(args)
{
  var t = typeof console; 
  if ( t && t != "undefined" ) {
    console.log(args);
  }
}

function process1(lvs_json_data) {
    var status_array = lvs_json_data["status"]
    var s = '';
    var len=status_array.length;
    mylog(["start :", lvs_json_data["host"] , 'cnt', len, new Date()].join(' ') );
    var clusterstatus = $('div#clusterstatus')
    var cldom = clusterstatus.clone();
    var portfwdstatus = $('div#portfwdstatus')
    var pfdom = portfwdstatus.clone();
    for ( var i=0; i<len; ++i ){
        var a = status_array[i];
        var fw = a[0];
        var wieght = a[1];
        var b ;
        var domid = ['div#fw',fw].join('');
        b = cldom.children(domid);
        if (!b) { 
          b = pfdom.children(domid);
        }
        if (b) { 
          b.css('display', 'block');
          var csscolor = css_wieght(wieght);
          b.css('background', csscolor);
          // var c = b.find('> .button')
          // c.click(function(domid) { var x = domid; return blindtoggle(x);});
        } 
    }
    mylog(["end loop: ", new Date()].join(''));
    clusterstatus.replaceWith(cldom);
    portfwdstatus.replaceWith(pfdom); 
    mylog(["build dom: ", new Date()].join(''));
//  "status": [["167778561",1],["167798273",400],["167799297",200],["167801857",1],["167802113",1],["167802369",1],["167803393",1],["167805442",1],["167805443",1],["2130710529",200],["2130710785",100],["2130712321",500],["2130716673",400],["2130716929",600],["2130719233",200],["2130724865",100],["2130725121",1],["2130725122",400],["2130725377",-1],["2130725889",200],["2130729473",200],["2130729729",200],["2130729985",200],["2130730241",400],["2130730497",200],["2130730753",200],["2130732289",1],["2131427329",300],["2133458945",100],["2137261313",1],["2137261569",1],["2137352194",-1],["2137352195",200],["2137352196",1],["2137352197",1],["2137352198",1],["2137352199",1],["2137352200",1]],
/////////////////////////////////////////////////
}
function css_wieght(w)
{
    if (w< 0 ) {
      return "steelblue"; // .downpage {  background: steelblue ; }
    } else if (w== 0 || w == 1 ) {
      return "#ff3d00"; // .red {  background: #ff3d00; }
    } else if (w> 1 && w<100 ) {
      return "yellow"; 
    } else if (w >= 100 ) {
      return "limegreen"; // "#00ff00"; //.up{ background: green ; }

    }
}
function get_wieght(wieght)
{
    if (wieght < 0 ) {
      return '<span class="downpage">Downpage</span>'
    } else if (wieght == 0 ) {
      return '<span class="down">Error</span>'
    } else if (wieght > 0 ) {
      return '<span class="up">Running</span>'
    }
}
function sched_label(s) 
{
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
}
function node_color_status(node, weight, activeconn, inactiveconn )
{
   var g = "green";
   var x = "gray";
   var down = "red";
   if ( weight == 0 ) {
      node.css('background',down);
      return down;
   } else if ( activeconn >= 0 || inactiveconn > 0 ) {
      node.css('background',g);
      return g;
   } else if ( activeconn > 0 ) {
      node.css('background',g);
      return g;
   } else if ( inactiveconn > 0 ) {
      node.css('background',g);
      return g;
   } else if ( activeconn ==  0 ) {
      node.css('background',g);
      return g;
   } else {
      node.css('background',x);
      return x;
   }
}
function node_status(node, weight, activeconn, inactiveconn)
{
   if ( weight == 0  ) {
      //node.css('background','red');
      return "down";
   } else if ( activeconn > 0 ) {
      //node.css('background','green');
      return "active";
   } else if ( inactiveconn > 0 ) {
      //node.css('background','green');
      return "idle wait";
   } else if ( activeconn ==  0 ) {
      //node.css('background','green');
      return "idle";
   } else {
      //node.css('background','gray');
      return "offline";
   }
}
function mk_sel(ip) {
    return ip.split('.').join('-').replace(':','-');
}

//"NODEIP": [ "Forward", Weight, ActConn, InActConns, ConnsEvr, InPkts, OutPkts, InBytes, OutBytes, CPS, InPPS, OutPPS, InBPS, OutPBS ], 

//  $("#list").html("Name:"+datos[1].name+"<br>"+"Last
// Name:"+datos[1].lastname+"<br>"+"Address:"+datos[1].address);
// }
//  # determines if the node is down:  true=down, false=up
//  def down?
//    weight.to_i == 0
//  # determines if the node is idle.
//  def idle?
//    activeconn.to_i == 0
//  # determines if the node is active
//  def active?
//    activeconn.to_i > 0
//  def inactive?
//    inactiveconn.to_i > 0
//  # determines if the node is offline (no activity at all)
//  def offline?
//   !active? && !idle? && !inactive?()
//  # determines node status, based on weight and activity
//  def nstat
//    if down?
//      :down
//    elsif idle?
//      :idle
//    elsif active?
//      :active
//    else
//      :offline
//  # maps the current node status to a color, from config
//  def NodeStatus.map_node_status_color(weight, activecnt, inactivecnt)
//    status = NodeStatus.map_node_status(weight, activecnt, inactivecnt)
//    ClusterConfig.map_node_status_color(status)

function thing() { return true; }

function get_new_data(hostname) {
      var d = window.lvs_data[hostname];
      if ( d) {
        lvs(d);
      } else{ 
        request = 'http://' + hostname +"lvs.json?9" ;
        aObj = new JSONscriptRequest(request);
        window.lvs_request[hostname]  = aObj;
        aObj.buildScriptTag();
        aObj.addScriptTag();
      }
}

// JSONscriptRequest -- a simple class for accessing Yahoo! Web Services
// using dynamically generated script tags and JSON
//
// Author: Jason Levitt
// Date: December 7th, 2005
//
// A SECURITY WARNING FROM DOUGLAS CROCKFORD:
// "The dynamic <script> tag hack suffers from a problem. It allows a page 
// to access data from any server in the web, which is really useful. 
// Unfortunately, the data is returned in the form of a script. That script 
// can deliver the data, but it runs with the same authority as scripts on 
// the base page, so it is able to steal cookies or misuse the authorization 
// of the user with the server. A rogue script can do destructive things to 
// the relationship between the user and the base server."
//
// So, be extremely cautious in your use of this script.
//
// Constructor -- pass a REST request URL to the constructor
function JSONscriptRequest(fullUrl) {
    // REST request path
    this.fullUrl = fullUrl; 
    // Keep IE from caching requests
    this.noCacheIE = '#noCacheIE=' + (new Date()).getTime();
    // Get the DOM location to put the script tag
    this.headLoc = document.getElementsByTagName("head").item(0);
    // Generate a unique script tag id
    this.scriptId = 'YJscriptId' + JSONscriptRequest.scriptCounter++;
}
// Static script ID counter
JSONscriptRequest.scriptCounter = 1;
// buildScriptTag method
JSONscriptRequest.prototype.buildScriptTag = function () {
    this.scriptObj = document.createElement("script");
    // Add script object attributes
    this.scriptObj.setAttribute("type", "text/javascript");
    this.scriptObj.setAttribute("src", this.fullUrl + this.noCacheIE);
    this.scriptObj.setAttribute("id", this.scriptId);
}
// removeScriptTag method Destroy the script tag
JSONscriptRequest.prototype.removeScriptTag = function () {
    this.headLoc.removeChild(this.scriptObj);  
}
// addScriptTag method
JSONscriptRequest.prototype.addScriptTag = function () {
    this.headLoc.appendChild(this.scriptObj);
}

$.jheartbeat = {
    options: {
        url: "heartbeat_default.asp",
        delay: 10000
    },
    beatfunction:  function(){ },
    timeoutobj:  { id: -1 },
    set: function(options, onbeatfunction) {
        if (this.timeoutobj.id > -1) {
            clearTimeout(this.timeoutobj);
        }
        if (options) {
            $.extend(this.options, options);
        }
        if (onbeatfunction) {
            this.beatfunction = onbeatfunction;
        }
        // Add the HeartBeatDIV to the page
        $("body").append("<div id=\"HeartBeatDIV\" style=\"display: none;\"></div>");
        this.timeoutobj.id = setTimeout("$.jheartbeat.beat();", this.options.delay);
    },

    beat: function() {
        $("#HeartBeatDIV").load(this.options.url);
        this.timeoutobj.id = setTimeout("$.jheartbeat.beat();", this.options.delay);
        this.beatfunction();
    }
};
//$(document).ready(function() {
//        $.jheartbeat.set({ url: "heartbeat.asp", delay: 3000 });
//});
function show_stats(fwmark) 
{
  var x = $(['div#fw',fwmark,' > table'].join(''));
  fill_in_stats(fwmark,x); 
  x.toggle('blind',{},0);
  return false;
}
function fill_in_stats(fwmark, elem)
{
    var cluster_data = null;
    var colo =  null;
    jQuery.each(window.load_balancers , function(idx,hostname) {
        var rawdata = window.lvs_data[hostname];
        var x = rawdata[fwmark];
        if (typeof x != 'undefined' && x ) {
          cluster_data = x;
          colo = lb_dc(hostname);
        }
    });
//"NODEIP": [ "Forward", Weight, ActConn, InActConns, ConnsEvr, InPkts, OutPkts, InBytes, OutBytes, CPS, InPPS, OutPPS, InBPS, OutPBS ], 
//  "167798273": {
//    "10.8.101.133:0": [ "Tunnel",100,0,6380,208402701,259979798,0,18569832813,0,41,43,0,2980,0 ], 
//    "totals": [ null,null,null,null,850759430,1091964626,0,77820091866,0,166,186,0,12935,0 ], 
//    "config": { "proto":"FWM","sched":"wlc","persist":"off","mask":"none" }  },
    var configline = elem.find('.config');
    configline.find('.proto').html(["Proto" , (cluster_data.config).proto ].join(' '));
    configline.find('.sched').html(sched_label((cluster_data.config).sched)); 
    if ( (cluster_data.config).persist == 'off' ) { 
      null; //configline.find('.persist').html(""]); 
    } else {
      configline.find('.persist').html("Persistance"); 
    }
    jQuery.each(cluster_data, function(key,val ) {
        if (key == "totals") {
            configline.find('.totalconn').html(val[4]);
            configline.find('.totalcps' ).html(val[9]);
            configline.find('.totalbps' ).html(val[7]);
            configline.find('.totalpps' ).html(val[10]);
        } else if ( key == "config" ) {
            null;
        } else {
            //"10.8.101.133:0":["Tunnel",100,0,6380,208402701,259979798,0,18569832813,0,41,43,0,2980,0], 
            var selector = null;
            var is_downpage = false;
            if ( /^127\.\d+\.\d+\.1:\d+$/.test(key)  ) {
              selector = ["#" ,"dp" , mk_sel(key)].join('') ;
              is_downpage = true;
            } else {
              selector = ["#" , colo , "-" , mk_sel(key)].join('') ;
            }
            var machineline = elem.find(selector) ;
            machineline.removeClass('nodata'); 
            machineline.find('.status > a').html( node_status( machineline, val[1] , val[2],val[3] )) ; 
            if (is_downpage) { 
              machineline.removeClass('nodownpage') ; 
              machineline.css('background','blue');
            } else { 
                machineline.css('background', node_color_status(machineline, val[1] , val[2],val[3] ) ); 
            }
//, Node IP,  Mgmt IP , Status,                 Wt,Active,Expire ,Totaln,Conn sec ,Pkts sec,Traffic sec, Total Reqs,Description
// 10.8.42.21  172.23.1.110 [1] [2] [3]   idle  100   0   0   0   0   0   0   345962  rabbit01 
/*  <td class="w75">Status</td>
     <td class="w120">Node</td>
     <td class="w50">Node Weight</td> raw
     <td class="w50">Active Conn</td> raw
     <td class="w50">Expire Conn</td> raw
     <td class="w50">Total Conn</td> active + expire
     <td class="w40">Conn sec</td>   CPS
     <td class="w40">Pkts sec</td>   InPPS
     <td class="w40">Traffic sec</td> ??? 
     <td class="w40">Total Reqs</td>  conns evr */
          //"NODEIP": [ "Forward", Weight, ActConn, InActConns, ConnsEvr, InPkts, OutPkts, InBytes, OutBytes, CPS, InPPS, OutPPS, InBPS, OutPBS ], 
           set_stat(machineline, 0, val, 0+1 ) ; //weight
           set_stat(machineline, 1, val, 1+1 ) ;
           set_stat(machineline, 2, val, 2+1 ) ;
           machineline.children('td.cnt').eq(3).text( val[2]+val[3] ) ; //total
           set_stat(machineline, 4, val, 9 ) ;
           set_stat(machineline, 5, val, 10 ) ;
           // machineline.children('td.cnt').eq(7).text( '???') ; //traffic sec
           set_stat(machineline, 6, val, 7 ) ;
           set_stat(machineline, 7, val, 4 ) ;
        } //end of else
    });
} /*end of function */

function set_stat(elem, eidx, values, vidx)
{
   elem.children('td.cnt').eq(eidx).text( values[vidx] ) ;
}



$(document).ready(function() {
    $("table tbody tr:nth-child(odd)").addClass("odd");
    $("table tbody tr:nth-child(even)").addClass("even");
    thing();
});
