//
// Global state
//
// map     - the map object
// usermark- marks the user's position on the map
// markers - list of markers on the current map (not including the user position)
// 
//

//
// First time run: request current location, with callback to Start
//
if (navigator.geolocation)  {
    navigator.geolocation.getCurrentPosition(Start);
}


function UpdateMapById(id, tag) {

  var target = document.getElementById(id);
  if(target){
    var data = target.innerHTML;
    var rows  = data.split("\n");
    for (i in rows) {
			var cols = rows[i].split("\t");
			var lat = cols[0];
			var long = cols[1];
			markers.push(new google.maps.Marker({ map:map,
										position: new google.maps.LatLng(lat,long),
										title: tag+"\n"+cols.join("\n")}));
		}
  }
}

function ClearMarkers() {
    // clear the markers
  while (markers.length>0) { 
		markers.pop().setMap(null);
  }
}


function UpdateMap() {
    var color = document.getElementById("color");
    
    color.innerHTML="<b><blink>Updating Display...</blink></b>";
    color.style.backgroundColor='white';

    ClearMarkers();
    if(document.getElementById("committeeid").checked){
      UpdateMapById("committee_data","COMMITTEE");
      $('#s1').html($('#stat1').html());
    }
    if(document.getElementById("candidateid").checked){
      UpdateMapById("candidate_data","CANDIDATE");
      $('#s2').html($('#stat2').html());
    }
    
    if(document.getElementById("individualid").checked){
      UpdateMapById("individual_data", "INDIVIDUAL");
    }
    if(document.getElementById("opinionid").checked){
      UpdateMapById("opinion_data","OPINION");
      $('#s3').html($('#stat3').html());
    }
    color.innerHTML="Ready";

    if (Math.random()>0.5) { 
			color.style.backgroundColor='blue';
    } else {
			color.style.backgroundColor='red';
    }
}

function NewData(data) {
  var target = document.getElementById("data");
  target.innerHTML = data;
  UpdateMap();
}

function ViewShift() {
    var bounds = map.getBounds();
    var ne = bounds.getNorthEast();
    var sw = bounds.getSouthWest();
    var color = document.getElementById("color");
    var what = "";
    if(document.getElementById("committeeid").checked){
      what = what + "committees,";
    }
    if(document.getElementById("candidateid").checked){
			what =  what + "candidates,";
    }
    if(document.getElementById("individualid").checked){
			what = what + "individuals,";
    }
    if(document.getElementById("opinionid").checked){
      what = what + "opinions,";
    }
    what = what.substring(0,(what.length - 1));
    color.innerHTML="<b><blink>Querying...("+ne.lat()+","+ne.lng()+") to ("+sw.lat()+","+sw.lng()+")</blink></b>";
    color.style.backgroundColor='white';
   
    // debug status flows through by cookie
    $.get("rwb.pl?act=near&latne="+ne.lat()+"&longne="+ne.lng()+"&latsw="+sw.lat()+"&longsw="+sw.lng()+"&format=raw&what="+what+"&cycle="+getCycles(), NewData);
}

function getCycles() {
	var cyclesString = "";
	$('input:checkbox:checked.cycletocheck').each(function(){
			if(cyclesString.length == 0){
			cyclesString = "\'"+$(this).val()+"\'";
			}
			else{
				cyclesString= cyclesString+",\'"+$(this).val()+"\'";
			}
			});
	console.log("cyclesArray: "+cyclesString);
	return cyclesString;
}

function Reposition(pos) {
    var lat=pos.coords.latitude;
    var long=pos.coords.longitude;

    map.setCenter(new google.maps.LatLng(lat,long));
    usermark.setPosition(new google.maps.LatLng(lat,long));
    document.cookie='Location='+lat+'/'+long;
}


function Start(location) {
  var lat = location.coords.latitude;
  var long = location.coords.longitude;
  var acc = location.coords.accuracy;
  
  var mapc = $( "#map");

  map = new google.maps.Map(mapc[0], 
			    { zoom:16, 
				center:new google.maps.LatLng(lat,long),
				mapTypeId: google.maps.MapTypeId.HYBRID
				} );

  usermark = new google.maps.Marker({ map:map,
					    position: new google.maps.LatLng(lat,long),
					    title: "You are here"});
  document.cookie='Location='+lat+'/'+long;
  markers = new Array;

  var color = document.getElementById("color");
  color.style.backgroundColor='white';
  color.innerHTML="<b><blink>Waiting for first position</blink></b>";

  google.maps.event.addListener(map,"bounds_changed",ViewShift);
  google.maps.event.addListener(map,"center_changed",ViewShift);
  google.maps.event.addListener(map,"zoom_changed",ViewShift);

  navigator.geolocation.watchPosition(Reposition);

}


