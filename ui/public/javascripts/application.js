// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
//
jQuery.noConflict();

function transferUser() {
   var searchCriteria = escape(document.getElementById('search_box').value); 
   var searchLink = '/node/host/' + searchCriteria
   window.location = searchLink;
  return false;
}
function search_keypress(e){ 
  var characterCode;
  if(e && e.which){ 
   e = e; characterCode = e.which; 
  } else{ 
   e = event; characterCode = e.keyCode; 
  }
  if (characterCode == 13) { return transferUser();} else{ return true; }
}

function remote_form_tag(div_id, form) 
{
  var url = form.getAttribute('action');
  new Ajax.Updater(div_id, url,
      {asynchronous:true, evalScripts:true, parameters:Form.serialize(form)}); 
  return false;
}
jQuery(document).ready(function() {
    // jQuery("table tbody tr:nth-child(odd)").addClass("odd");
    jQuery("table tbody tr:nth-child(even)").addClass("even");
});
