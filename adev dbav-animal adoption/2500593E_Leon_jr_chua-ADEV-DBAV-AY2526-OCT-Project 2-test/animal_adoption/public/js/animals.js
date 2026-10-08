
function loadanimaldata(){
    var animalarray=[];
    fetch('/animals', {
        method: 'GET' // Specify the HTTP method (GET in this case)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json(); // Parse the JSON response
    })
    .then(data => {
        //retrieve response and store it in animalArray
        animalarray = data
        //print out the array in console
        insertdynamicanimalsbasic(animalarray);

    })
    .catch(error => {
        console.error('Error:', error); // Handle errors
    });
}
//===================
//=======Home Page=====
//===================
function insertdynamicanimalsbasic(arrayOfanimals){
    var dynamicanimalslist = document.getElementById("dynamicanimalsdatalist");

    //class for CSS styling
    var newContent="<table class='animal-table'><tr>";
    
    var isadmin = document.body.dataset.role ==="admin";

    // Loop through the animalsArray elements
    for (var i = 0; i < arrayOfanimals.length; i++) {
        console.log(arrayOfanimals[i].name,arrayOfanimals[i].image_url)
    // Log the current animals object to the console
        console.log(arrayOfanimals[i]);
        // Build up the HTML string for this animals

    //determins status colour
        var statuscolor ="";
        if (arrayOfanimals[i].adoption_status ==="Available") {
            statuscolor = "style='background-color: #c8e6c9; color: #2e7d23;'";
        } 
        else if (arrayOfanimals[i].adoption_status ==="Reserved") {
            statuscolor = "style='background-color: #ffe0b2; color: #ca622a;'";
        }
        else if (arrayOfanimals[i].adoption_status ==="Adopted") {
            statuscolor = "style='background-color: #e0e0e0; color: #616161;'";
        }
        newContent +=
            "<td class='animal-card'>"+  

            "<img src='" + arrayOfanimals[i].image_url + "'> <br>"+
            
            "<div class='animal-header'>" +
                "<h4>" + arrayOfanimals[i].name + "</h4>" +
                "<div class='status-badge' "+ statuscolor +">" + arrayOfanimals[i].adoption_status + "</div>" +
            "</div>"+

            "<div class='animal-data'>" +
                "<div><span>Age:</span>" + arrayOfanimals[i].age_year +"y " +arrayOfanimals[i].age_month +"mths" + "</div>" +
                "<div><span>Species:</span>" + arrayOfanimals[i].species + "</div>" +
                "<div><span>Breed:</span>" + arrayOfanimals[i].breed + "</div>" +

            "</div>"+

            "<div class='animal-btns'>" +
                "<button type='button' class='btn btn-view' type='button' onclick='viewanimaldetails(this)' restId='" + arrayOfanimals[i].id + "'>View</button>";

            if (isadmin){
                newContent +=
               //admin buttons
                    "<button type='button' class='btn btn-edit' type='button' onclick='editanimals(this)' restId='" + arrayOfanimals[i].id + "'>Edit</button>" +
                    "<button type='button' class='btn btn-delete' type='button' onclick='deleteanimalsdata(this)' restId='"+arrayOfanimals[i].id+"'>Delete</button>";    
            }

            newContent +=
            "</div>"+

            "</td>";
        // After every third animals, end the current row and start a new one
        if ((i + 1) % 3 === 0 && i < arrayOfanimals.length - 1) {
            newContent += "</tr><tr>";
        }
    }
    newContent += "</tr></table>";
    //show the static content
    dynamicanimalslist.innerHTML = newContent;
}
let allanimalsdata = [];
let currentfilter = null;
let selectedspecies = ""; 

function setupspeciesfilterui() {
    var speciescontainer = document.getElementById("speciesfiltercontainer");
    if (!speciescontainer) return;

    // Build unique species list from allanimalsdata
    var speciesset = new Set();
    for (var i = 0; i < allanimalsdata.length; i++) {
        if (allanimalsdata[i].species) speciesset.add(allanimalsdata[i].species);
    }

    var specieslist = Array.from(speciesset).sort();

    // Create species filter boxes (similar to stat containers for adoption status)
    var speciesboxescontent = "";
    for (var i = 0; i < specieslist.length; i++) {
        var species = specieslist[i];
        
        // Count how many animals of this species exist
        var speciescount = 0;
        for (var j = 0; j < allanimalsdata.length; j++) {
            if (allanimalsdata[j].species === species) {
                speciescount++;
            }
        }

        // Create box with species name and count (like the stat boxes)
        speciesboxescontent += 
            "<div class='species-container' data-species='" + species + "'>" +
                "<div class='species-name'>" + species + "</div>" +
                "<div class='species-count'>" + speciescount + "</div>" +
            "</div>";
    }

    speciescontainer.innerHTML = speciesboxescontent;

    //Set up click listeners for each species box
    setupspeciesclicklisteners();
}

// clicking a species filters by that species, clicking again clears the filter
function setupspeciesclicklisteners() {
    var speciescontainers = document.querySelectorAll('.species-container');

    for (var i = 0; i < speciescontainers.length; i++) {
        speciescontainers[i].addEventListener('click', function() {
            var species = this.getAttribute('data-species');
            handlespeciesclick(species);
        });
    }
}

// If clicking the same species again, clears the filter
function handlespeciesclick(species) {
    // If clicking the same filter again then clear
    if (selectedspecies === species) {
        clearallfilters();
        return;
    }

    // If not, apply species filter
    filteranimalbyspecies(species);
    setactivespeciescontainer(species);
}

function filteranimalbyspecies(species) {
    selectedspecies = species;   
    applyallfilters();           
}
function filteranimalsbystatus(status) {
    currentfilter = status;  
    applyallfilters();        
}
function togglefilters(){
  var panel = document.getElementById("filterPanel");
  panel.classList.toggle("open");
}
// click outside to close the filters 
document.addEventListener("click", function(e){
  var panel = document.getElementById("filterPanel");
  var wrap = document.querySelector(".filter-float");
  if (!panel || !wrap) return;

  if (panel.classList.contains("open") && !wrap.contains(e.target)){
    panel.classList.remove("open");
  }
});

function setactivespeciescontainer(species) {
    var speciescontainers = document.querySelectorAll('.species-container');

    // Remove active class from all containers
    for (var i = 0; i < speciescontainers.length; i++) {
        speciescontainers[i].classList.remove('active');
    }

    // Add active class to the clicked container
    var activecontainer = document.querySelector('.species-container[data-species="' + species + '"]');
    if (activecontainer) {
        activecontainer.classList.add('active');
    }
}

function loadadoptionstatusstat() {
    //If this page doesnt have the stats ui element, dont run this function
    var statavailableele = document.getElementById("stat-available");
    var statreservedele  = document.getElementById("stat-reserved");
    var statadoptedele   = document.getElementById("stat-adopted");

    if (!statavailableele || !statreservedele || !statadoptedele) return;

    fetch("/animals", {
        method: 'GET'
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json();
    })
   .then(data => {
        allanimalsdata = data; // Store all animals data
        var available = 0, reserved = 0, adopted = 0;

        // Loop through animals and count by adoption status
        for (var i = 0; i < allanimalsdata.length; i++) {
            if (allanimalsdata[i].adoption_status === "Available") {
                available++;
            } 
            else if (allanimalsdata[i].adoption_status === "Reserved") {
                reserved++;
            } 
            else if (allanimalsdata[i].adoption_status === "Adopted") {
                adopted++;
            }
        }

        // Set the text content for each stat element
        document.getElementById("stat-available").textContent = available;
        document.getElementById("stat-reserved").textContent = reserved;
        document.getElementById("stat-adopted").textContent = adopted;

        
        setupstatclicklisteners();
        // CHANGED: Added call to setup species filter boxes after loading animal data
        setupspeciesfilterui();
    })
    .catch(error => {
        console.error('Error:', error);
    });
}
// Basically means that When the page finished loading THEN load this function 
document.addEventListener("DOMContentLoaded", function() {
    loadadoptionstatusstat();
});

// makes the stat boxes clickable so users can filter animals by adoption status. 
function setupstatclicklisteners() {
    var availableContainer = document.querySelector('.stat-container.available');
    var reservedContainer = document.querySelector('.stat-container.reserved');
    var adoptedContainer = document.querySelector('.stat-container.adopted');

    if (availableContainer) {
        availableContainer.addEventListener('click', function() {
            handlestatclick('Available','available')
        });
    }

    if (reservedContainer) {
        reservedContainer.addEventListener('click', function() {
            handlestatclick('Reserved','reserved')
        });
    }

    if (adoptedContainer) {
        adoptedContainer.addEventListener('click', function() {
            handlestatclick('Adopted','adopted')
        });
    }
}


// Set the active stat container
function setactivestatcontainer(activeClass) {
    var statcontainers = document.querySelectorAll('.stat-container');

    // Remove active class from all containers
    for (var i = 0; i < statcontainers.length; i++) {
        statcontainers[i].classList.remove('active');
    }

    // Add active class to the clicked container
    var activeContainer = document.querySelector('.stat-container.' + activeClass);
    if (activeContainer) {
        activeContainer.classList.add('active');
    }
}
function clearallfilters() {
    // Show ALL animals
    insertdynamicanimalsbasic(allanimalsdata);  
    // Reset filter variables
    currentfilter = null;
    selectedspecies = "";
    
    // Remove active class from all stat containers
    var statcontainers = document.querySelectorAll('.stat-container');
    for (var i = 0; i < statcontainers.length; i++) {
        statcontainers[i].classList.remove('active');
    }

    // NEW: Remove active class from all species containers
    var speciescontainers = document.querySelectorAll('.species-container');
    for (var i = 0; i < speciescontainers.length; i++) {
        speciescontainers[i].classList.remove('active');
    }
}
function handlestatclick(status, cssclass) {
    // If clicking the same filter again then clear
    if (currentfilter === status) {
        clearallfilters();
        return;
    }

    // if not, apply filter
    filteranimalsbystatus(status);
    setactivestatcontainer(cssclass);
}
// It checks each filter and only shows animals that match ALL selected filters
function applyallfilters() {
    var filtered = allanimalsdata;

    // Filter by adoption status if one is selected
    if (currentfilter) {
        filtered = filtered.filter(function(animal) {
            return animal.adoption_status === currentfilter;
        });
    }

    // Filter by species if one is selected
    if (selectedspecies) {
        filtered = filtered.filter(function(animal) {
            return animal.species === selectedspecies;
        });
    }

    // Display the filtered results (only animals matching all active filters)
    insertdynamicanimalsbasic(filtered);
}



function viewanimaldetails(btnElement){
    var id = btnElement.getAttribute("restId");
    var role= document.body.dataset.role;

    if (role==="admin") {
        location.href ="/admin_animaldetails.html?id="+id;
    } else {
        location.href ="/public_animaldetails.html?id="+id;
    }
}

function deleteanimalsdata(buttonElement) {

    const confirmdelete=confirm("Delete this pet? cannot be undone.")
    if (!confirmdelete) return;

    var id = buttonElement.getAttribute("restId");
    var api_url = "/animals/"+ id;

    fetch(api_url, {
        method: 'DELETE'
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: Failed to delete animal (DELETE) (deleteAnimalData)')
        }
        return response.json(); //parse the text response
    })
    .then(data => {
        location.href = "/admin_homepage.html"; //Print out the response using console.log
    })
    .catch(error => {
        console.error('Error encountered:',error); //Handle errors
    });

}



//==================
//add page
//=================
function addanimaldata(){
    var formElement = document.getElementById('insertForm'); //retrieve the from element by id
    var formData = new FormData(formElement); //create a formdata object from the form element
    var animaldata = Object.fromEntries(formData.entries()); //convert formdata to a plain object that is a converitble to JSON

    animaldata.default_image=1;

    // Get all extra image URLs
    var extraimagearray=[];
    var extraimageinputs = formData.getAll("extra_image_url")

    for (var i=0; i<extraimageinputs.length; i++) {
        var url = extraimageinputs[i].trim();
        if (url !== "") {
            extraimagearray.push(url)
        }
    }

    var jsonString = JSON.stringify(animaldata); // Convert Object to JSON String

    //new animal image will always have default image set to 1(true)
    

    fetch('/animals', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: jsonString, //Json in string
    })
    .then (response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json()}) //or response.text() if you want to convert it to text
    .then (data => {
        // Get the animal ID from the response
        var animalId = data.insertId;

        // If there are extra images, add them
        if (extraimagearray.length > 0) {
            addextraimages(animalId, extraimagearray);
        } else {
            // If no extra images, redirect immediately
            gobacktohome();
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert("Failed to add animal. Please try again.")
    })
}

function loadspeciesdropdown() {
    fetch('/species')
        .then(response => response.json())
        .then(speciesList => {
            var speciesSelect = document.getElementById("species_id");
            if (!speciesSelect) return;

            speciesSelect.innerHTML = "<option value=''>Select species</option>";

            for (var i = 0; i < speciesList.length; i++) {
                var option = document.createElement("option");
                option.value = speciesList[i].id;
                option.textContent = speciesList[i].name;
                speciesSelect.appendChild(option);
            }
        })
        .catch(error => console.error("Error loading species:", error));
}

function loadbreedsdropdown(speciesid) {
    var breedidselected = document.getElementById("breed_id");
    if (!breedidselected) return;

    //if no species selected reset the breed dropdown
    if (speciesid ==="" || speciesid ===null) {
        breedidselected.innerHTML = "<option value=''>Select breed</option>";
        return;
    }
    //return is impt here so that in setanimaldetail, it will return the breed for animal id
    return fetch('/species/'+speciesid + '/breeds')
        .then(response => {
            if (!response.ok) {
                throw new Error('Error: Failed to load breed')
            }
            return response.json(); //parse the text response
        })

        .then(function (breedlistfromserver) {

            // Clear dropdown
            breedidselected.innerHTML = "<option value=''>Select breed</option>";

            // Add breed options
            for (var index = 0; index < breedlistfromserver.length; index++) {
                var breed = breedlistfromserver[index];

                var option = document.createElement("option");
                option.value = breed.id;
                option.textContent = breed.name;

                breedidselected.appendChild(option);
            }
        })
        .catch(function (error) {
            console.error("Error loading breeds:", error);
        });
}

function loaddropdownforms() {
    loadspeciesdropdown();
    var speciesselectelement = document.getElementById("species_id");

    // whenever the user changes selected species, run this function
    speciesselectelement.addEventListener("change", function () {
        //reloads breeds with new species value
        loadbreedsdropdown(this.value);
    });
    //clears breed dropdown
    loadbreedsdropdown("");
}

function addextraimages(animalId, extraImageArray) {

    for (var i = 0; i < extraImageArray.length; i++) {

        fetch('/animals/' + animalId + '/images', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                image_url: extraImageArray[i]
            })
        })
        .catch(function (error) {
            console.error("Failed to add extra image:", error);
        });
    }

    
    gobacktohome();
}
function addextraimageinput() {
    var container = document.getElementById("extraimagescontainer");

    var wrapper = document.createElement("div");
    wrapper.className = "extra-image-row";

    var input = document.createElement("input");
    input.type = "text";
    input.name = "extra_image_url"; // IMPORTANT: matches FormData.getAll
    input.placeholder = "Enter extra image URL";
    input.className = "imageurlinput";

    var deleteBtn = document.createElement("button");
    deleteBtn.type = "button";
    deleteBtn.textContent = "✕";
    deleteBtn.className = "delete-image-btn";

    deleteBtn.addEventListener("click", function () {
        wrapper.remove();
    });

    wrapper.appendChild(input);
    wrapper.appendChild(deleteBtn);
    container.appendChild(wrapper);
}

//============
//edit page
//=================

function editanimals(btnElement) {
    var id = btnElement.getAttribute("restId");
    location.href="/update_animals.html?id="+id;
}

function loadanimaldetail() {
    var animalArray=[];
    var params = new URLSearchParams(location.search);
    var id =params.get('id');
    var api_url = '/animals/'+id;

    fetch(api_url, {
        method: 'GET' // Specify the HTTP method (GET in this case)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }   
        return response.json(); // Parse the JSON response
    })
    .then(data => {
        //retrieve response and store it in animalArray
        animalArray = data;
        //print out the animalArray in console to see the data.
        setanimaldetail(animalArray[0])
    })
    .catch(error => {
        console.error('Error:', error); // Handle errors
    });
}

function setanimaldetail(animal)
{

    fetch('/species')
        .then(function (response) {
            return response.json();
        })
        .then(function (specieslist) {
            var speciesselect = document.getElementById("species_id");
            if (!speciesselect) return;

            speciesselect.innerHTML = "<option value=''>Select species</option>";

            for (var i = 0; i < specieslist.length; i++) {
                var option = document.createElement("option");
                option.value = specieslist[i].id;
                option.textContent = specieslist[i].name;
                speciesselect.appendChild(option);
            }
            document.getElementById('species_id').value = animal.species_id;

            loadbreedsdropdown(animal.species_id).then(function () {
                document.getElementById("breed_id").value = animal.breed_id
            });

            var speciesselectelement = document.getElementById('species_id');
            speciesselectelement.addEventListener('change', function() {
                loadbreedsdropdown(this.value); 
                });               
        })
    .catch(function (error) {
        console.error("Error loading species:", error); 
    }); 
    
    document.getElementById("breed_id").value = animal.breed_id;

    document.getElementById('id').value = animal.id;

    document.getElementById('name').value = animal.name;
    document.getElementById('age_year').value = animal.age_year;
    document.getElementById('age_month').value = animal.age_month;
    document.getElementById('temperament').value = animal.temperament
    
    if (animal.gender ==="Male") {
        document.getElementById('Male').checked=true;
    } else if (animal.gender==="Female"){
        document.getElementById('Female').checked=true;
    }

    if (animal.adoption_status ==="Available") {
        document.getElementById('Available').checked=true;
    } 
    else if (animal.adoption_status==="Reserved"){
        document.getElementById('Reserved').checked=true;
    }
    else if (animal.adoption_status==="Adopted"){
        document.getElementById('Adopted').checked=true;
    }

}


function updateanimalsdata(){
    var params = new URLSearchParams(location.search);
    var id = params.get('id');
    var api_url='/animals/'+id;
    var formElement = document.getElementById('updateanimalsform');
    var formData = new FormData(formElement);
    var animaldata= Object.fromEntries(formData.entries());
    


    var jsonString = JSON.stringify(animaldata)

    fetch(api_url, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        },
        body: jsonString
    })
    .then(response => {
        if(!response.ok){
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json()// or response.text() if you expect a text
    })
    .then(data => {
        location.href="/admin_homepage.html";
    })
    .catch(error => {
        console.error('Error:', error);
    });
}


//==========================
//for detail page
function loadanimaldetails() {
    var animalArray=[];
    var params = new URLSearchParams(location.search);
    var id =params.get('id');
    var api_url = '/animals/'+id;

    fetch(api_url, {
        method: 'GET' // Specify the HTTP method (GET in this case)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }   
        return response.json(); // Parse the JSON response
    })
    .then(data => {
        animalArray = data;
        displayanimaldetails(animalArray[0])
        loadanimalimages(id)
    })
    .catch(error => {
        console.error('Error:', error); // Handle errors
    });
}

function loadanimalimages(animalid) {
    var api_url = '/animals/'+animalid+'/images';

    fetch(api_url, {
        method: 'GET' // Specify the HTTP method (GET in this case)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }   
        return response.json(); // Parse the JSON response
    })
    .then(images => {
        displayanimalimages(images);
    })
    .catch(error => {
        console.error('Error:', error); // Handle errors
    });
}

function displayanimalimages(images) {
    var imagecontainer=document.getElementById("animalimagescontainer");

    var defaultimage =images.find(function(image){
        return image.is_default ==1;
    });

    var content=
        "<div class='image-gallery'>"+

            "<div class='main-image-container'>" +
                "<img class='mainimage' id='mainimage' src='" + defaultimage.image_url + "'>" +
            "</div>";

    if (images.length > 1) {
        content += "<div class='gallery-preview'>";
        
        for (var i=0; i <images.length; i++) {
            
            content+= 
                "<div class='preview-item'>" +
                "<img class='thumbnail' src='" + images[i].image_url +
                 "' onclick='switchimage(\"" + images[i].image_url + "\") ' >" +
                "</div>";
        }
        content += "</div>";
    }
    content += "</div>";
    imagecontainer.innerHTML=content;

}

function switchimage(imageurl) {
    document.getElementById('mainimage').src = imageurl;
}


function displayanimaldetails(animal){
    var dynamicanimalslist = document.getElementById("animaldetailscontainer");

    var isadmin = document.body.dataset.role ==="admin";

    var content =
        "<div class='animal-detail-card'>" +
            "<div class='animal-info'>"+
                "<h2 class='animal-name'>" + animal.name + "</h2>" +
                "<div class='animal-details'>"+
                    "<p><strong>Age:</strong>" + animal.age_year + "years, " + animal.age_month + "months</p>"+
                    "<p><strong>Gender:</strong>" + animal.gender  + "</p>"+
                    "<p><strong>Species:</strong>" + animal.species  + "</p>"+
                    "<p><strong>Breed:</strong>" + animal.breed  + "</p>"+
                    "<p><strong>Temperament/Personality:</strong>" + animal.temperament  + "</p>"+
                    "<p><strong>Adoption Status:</strong>" + animal.adoption_status + "</p>"+
        "</div>";

    if (isadmin) {
        content+=
            "<div class= 'animal-buttons'>"+
                "<button class='btn btn-edit' type='button' onclick='editanimals(this)' restId='" + animal.id + "'>Edit</button>" +
                "<button class='btn btn-delete' type='button' onclick='deleteanimalsdata(this)' restId='"+animal.id+"'>Delete</button>" ;
            "</div>"
        }
    content+=
                "</div>"+
            "</div>"+
        "</div>";


    dynamicanimalslist.innerHTML = content;
}

function deleteanimalfromdetail(buttonElement) {

    const confirmdelete=confirm("Delete this pet? cannot be undone.")
    if (!confirmdelete) return;
    var id = new URLSearchParams(location.search).get('id')

    fetch("animals/"+id, {
        method: 'DELETE'
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: Failed to delete animal (DELETE) (deleteAnimalData)')
        }
        return response.json(); //parse the text response
    })
    .then(data => {
        location.href = "/public_homepage.html"; //Print out the response using console.log
    })
    .catch(error => {
        console.error('Error encountered:',error); //Handle errors
    });

}

//manage images page

function getanimalidfromurl() {
    var params= new URLSearchParams(location.search);
    return params.get('id');
}

function loadmanageimages() {
    var id = getanimalidfromurl();

    var api_url="/animals/"+id+ "/images/";

    fetch(api_url, {
        method: 'GET'
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please chec logs')
        }
        return response.json(); 
    })
    .then(data => {
        imagearray=data; 
        
        displaymanageimages(id, imagearray)
    })
    .catch(error => {
        console.error('Error encountered:',error); //Handle errors
    });

}

function displaymanageimages(animalid, imagearray) {
    var defaultsection= document.getElementById("defaultimagesection")
    var othersection= document.getElementById("otherimagesection")


    //defaultimage to hold 1 object but hasnt found it yet
    var defaultimage = imagearray.find(function(image){
        return image.is_default ==1;
    })


    var otherimages =[];

    for (var i=0; i< imagearray.length; i++) {
        if (imagearray[i].is_default == 1) {
            defaultimage=imagearray[i];
        } else {
            otherimages.push(imagearray[i])
        }
    }

    var defaultimgcontent = "<h3>Default Image</h3>";

    defaultimgcontent +=
        "<img src='" +defaultimage.image_url + "' class='defaultimage-preview'><br><br>"+
        "<input type='text' id='replacedefaulturl' class='imageurlinput' placeholder='Enter new URL to replace this image' required><br>"+
        "<button class='btn replace-default-img' onclick='replacedefaultimage()  '>Replace Default Image</button>";
    defaultsection.innerHTML =defaultimgcontent;

    if (otherimages.length ===0) {
        othersection.innerHTML = "<p> No extra images.</p>"
        return;
    }

    var otherimagecontent = "<div class='other-images-wrap'>";

    for (var j =0; j<otherimages.length; j++) {
        otherimagecontent +=
            "<div class='extra-image-card'>" +
                "<img src='" + otherimages[j].image_url + "' class='extra-image'>"+

                

                "<input type='text' id='replaceotherurl" + otherimages[j].id + "' class='imageurlinput' " +
                "placeholder='Enter new URL to replace this image'>" +

                "<div class='extra-image-actions'>" +

                    "<button class='btn set-default' onclick='setdefaultimage(" + animalid + "," + otherimages[j].id + ")'>Set as Default</button>" +

                    "<button class='btn replace-img' onclick='replaceextraimage(" + animalid + "," + otherimages[j].id + ")'>Replace Image</button>" +

                    "<button  class='btn delete-img' onclick='deleteextraimage("+ animalid+","+ otherimages[j].id+")'><i class='fas fa-trash'></i></button>" +
                "</div>" +
            "</div>";
    }

    otherimagecontent += "</div>";
    othersection.innerHTML=otherimagecontent
}

function replacedefaultimage(){
    var animalid = getanimalidfromurl();
    // .trim removes spaces at the start/end for error handling
    var newurl = document.getElementById("replacedefaulturl").value.trim()
    if (newurl==="") {
        alert("Please enter an image URL")
        return;
    }
    var imagedata= {image_url:newurl};
    var jsonString = JSON.stringify(imagedata);

    fetch('/animals/' +animalid+"/images/default", {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        },
        body: jsonString
    })
    .then(response => {
        if(!response.ok){
            throw new  Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json()// or response.text() if you expect a text
    })
    .then(data => {
        loadmanageimages();
    })
    .catch(error => {
        console.error('Error:', error);
    });
}

function addextraimage(){
    var animalid = getanimalidfromurl();
    var urlinput = document.getElementById("newimageurl");
    //trim to remove spaces and front/end of input
    var imageurl = urlinput.value.trim();

    if (imageurl==="") {
        alert("Please enter an image URL")
        return;
    }

    var imagedata = {image_url: imageurl}
    var jsonString = JSON.stringify(imagedata);

    fetch('/animals/' +animalid+"/images", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: jsonString, //Json in string
    })
    .then (response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json()}) //or response.text() if you want to convert it to text
        
    .then (data => {
        urlinput.value="";
        loadmanageimages();
    })
    .catch(error => {
        console.error('Error:', error);
    })
}

function replaceextraimage( animalid, imageid) {
    var input = document.getElementById ( "replaceotherurl" + imageid);
    var newURL= input.value.trim();

    if (newURL ==="") {
        alert("please enter a New URL");
        return;
    }

    var jsonString = JSON.stringify({image_url:newURL})

    fetch('/animals/' +animalid+"/images/" + imageid, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        },
        body: jsonString, //Json in string
    })
    .then (response => {
        if (!response.ok) {
            throw new Error('Error: The response was not ok, please check logs for error message.');
        }
        return response.json()}) //or response.text() if you want to convert it to text
        
    .then (data => {
        loadmanageimages();
    })
    .catch(error => {
        console.error('Error:', error);
    })
}

function deleteextraimage(animalid, imageid) {

    const confirmdelete=confirm("Delete this image? cannot be undone.")
    if (!confirmdelete) return;


    fetch('/animals/'+animalid+'/images/'+imageid, {
        method: 'DELETE'
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: Failed to delete animal (DELETE) (deleteAnimalData)')
        }
        return response.json(); //parse the text response
    })
    .then(data => {
        loadmanageimages(); //Print out the response using console.log
    })
    .catch(error => {
        console.error('Error encountered:',error); //Handle errors
    });

}

function setdefaultimage(animalid, imageid) {
    fetch('/animals/' + animalid + '/images/' + imageid + '/default', {
        method: 'PUT'
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Error: response was not ok');
        }
        return response.json();
    })
    .then(data => {
        // reload your manage images UI
        loadmanageimages(); // (use whatever function you already have)
    })
    .catch(error => {
        console.error('Error:', error);
    });
}
//go back to specific home page, eg admin go to admin homepage

function gobacktohome() {
    var params = new URLSearchParams(location.search);
    var from = params.get("from");

    if (from==="admin") {
        location.href = "/admin_homepage.html";
    } else {
        location.href = "/public_homepage.html";
    }
}