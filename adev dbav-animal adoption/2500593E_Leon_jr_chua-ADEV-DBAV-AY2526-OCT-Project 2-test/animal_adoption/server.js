var express = require("express");
var db= require("./db-connections");
var app= express();
app.use(express.json());
app.use(express.static("./public"));

// error handling method 1 input validation
function isnonnegint(x) {
    return Number.isInteger(x) && x >= 0;
}

// returns a string error message if invalid, otherwise returns null
function validateADDanimalinputs(body) {
    const allowedstatus = ["Available", "Reserved", "Adopted"];
    const allowedgender = ["Male", "Female"];

    const name = String(body.name || "").trim();
    const ageYear = Number(body.age_year);
    const ageMonth = Number(body.age_month);
    const speciesId = Number(body.species_id);
    const breedId = Number(body.breed_id);
    const gender = String(body.gender || "").trim();
    const adoptionStatus = String(body.adoption_status || "").trim();
    const imageUrl = String(body.image_url || "").trim(); 
    const temperament = String(body.temperament || "").trim()

    if (!name) return "Name is Required"
    if (name.length >30) return "Name must be 30 Characters or less";

    if (!temperament) return "Temperament is Required"
    if (temperament.length >150) return "Temperament/Personality must be 150 Characters or less"

    if (!isnonnegint(ageYear))
    return "age_year must be a non-negative integer";

    if (!isnonnegint(ageMonth) || ageMonth > 11)
    return "age_month must be an integer from 0 to 11";

    if (!allowedgender.includes(gender))
    return "gender must be Male or Female";

    if (!allowedstatus.includes(adoptionStatus))
    return "adoption_status must be Available, Reserved, or Adopted";

    if (!Number.isInteger(speciesId) || speciesId <= 0)
    return "species_id must be a positive integer";

    if (!Number.isInteger(breedId) || breedId <= 0)
    return "breed_id must be a positive integer";

    if (!imageUrl)
    return "image_url is required";

    return null;
}

function validateUPDATEanimalinputs(body) {
    const allowedstatus = ["Available", "Reserved", "Adopted"];
    const allowedgender = ["Male", "Female"];

    const name = String(body.name || "").trim();
    const ageYear = Number(body.age_year);
    const ageMonth = Number(body.age_month);
    const speciesId = Number(body.species_id);
    const breedId = Number(body.breed_id);
    const gender = String(body.gender || "").trim();
    const adoptionStatus = String(body.adoption_status || "").trim();
    const temperament = String(body.temperament || "").trim()

    if (!name) return "Name is Required"
    if (name.length >30) return "Name must be 30 Characters or less";

    if (!temperament) return "Temperament is Required"
    if (temperament.length >150) return "Temperament/Personality must be 150 Characters or less"

    if (!isnonnegint(ageYear))
    return "age_year must be a non-negative integer";

    if (!isnonnegint(ageMonth) || ageMonth > 11)
    return "age_month must be an integer from 0 to 11";

    if (!allowedgender.includes(gender))
    return "gender must be Male or Female";

    if (!allowedstatus.includes(adoptionStatus))
    return "adoption_status must be Available, Reserved, or Adopted";

    if (!Number.isInteger(speciesId) || speciesId <= 0)
    return "species_id must be a positive integer";

    if (!Number.isInteger(breedId) || breedId <= 0)
    return "breed_id must be a positive integer";

    return null;
}

//Retrieval RESTful API (get all)
app.route('/animals').get(function (req,res) {
    var sql = `
        SELECT 
            animals.*, species.name AS species, breeds.name AS breed, animal_images.image_url 
            FROM animals 
            LEFT JOIN species ON animals.species_id = species.id 
            LEFT JOIN breeds ON animals.breed_id = breeds.id 
            LEFT JOIN animal_images ON animal_images.animal_id = animals.id AND animal_images.is_default = 1
    `;
    db.query(sql, function(error,result) {
        if (error) {    
            return res.status(500).json({ error: "Database error fetching animals" });
        } else {
            res.json(result);
        }
    });
});

//retrieval restful api (get one)
app.route('/animals/:id').get(function (req,res) {
    var sql = `
        SELECT 
            animals.*, species.name AS species, breeds.name AS breed, animal_images.image_url
        FROM animals
        LEFT JOIN species ON animals.species_id = species.id
        LEFT JOIN breeds ON animals.breed_id = breeds.id
        LEFT JOIN animal_images 
            ON animal_images.animal_id = animals.id 
            AND animal_images.is_default = 1
        WHERE animals.id = ?
    `;

    var parameter=[req.params.id];

    db.query(sql,parameter, function(error,result) {
        if (error) {
            return res.status(500).json({ error: "Database error fetching animal" });
        } else {
            res.json(result);
        }
    });
});

//special feature
app.route('/animals/status').get(function (req,res) {
    var sql =` SELECT adoption_status,
     COUNT(*) as count FROM animal_adoption.animals 
     WHERE adoption_status IN ('Available','Adopted','Reserved') 
     GROUP BY adoption_status 
     `;
    db.query(sql, function(error, result) {
        if (error) {
            return res.status(500).json({ error: "Database error fetching adoption status stats" });
        } else {
            // Format the results
            var stats = {
                available: 0,
                reserved: 0,
                adopted: 0,
                total: 0
            };
            
            var totalCount = 0;
            
            result.forEach(function(row) {
                stats[row.adoption_status] = row.count;
                totalCount += row.count;
            });
            
            stats.total = totalCount;
            
            res.json(stats);
        }
    });
})

//insert restful api (post to insert)
app.route("/animals").post(function (req,res){

    //error handling
    var errormsg = validateADDanimalinputs(req.body);
    if (errormsg) {
        return res.status(400).json({error: errormsg});
    }

    //sql to insert data into animal table
        var sql = `
        INSERT INTO animal_adoption.animals
        (name, age_year, age_month, gender, species_id, breed_id, temperament, adoption_status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `;

    var parameter = [
        req.body.name,
        req.body.age_year,
        req.body.age_month,
        req.body.gender,
        req.body.species_id,
        req.body.breed_id,
        req.body.temperament,
        req.body.adoption_status
    ];

    //Perform database query
    db.query(sql, parameter, function(error, result){
        if(error)
        {
            return res.status(500).json({ error: "Database error inserting animal" });
        }
        else{
            var animalid = result.insertId;

            var sql2 = "INSERT INTO animal_adoption.animal_images (animal_id, image_url, is_default) VALUES (?,?,1)";
            var parameter2= [animalid, req.body.image_url];

            db.query(sql2,parameter2, function(error2,result2) {
                if(error2){
                    return res.status(500).json({ error: "Database error inserting default image" });
                } else{
                    res.json({
                        //return animal id so frontend knows which animal was created
                        insertId: animalid
                    })
                }
            })

        }
    });

});


//animals put to update data
app.route("/animals/:id").put(function (req,res){

    var id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
        return res.status(400).json({ error: "id must be a positive integer" });
    }

    var errormsg = validateUPDATEanimalinputs(req.body);
    if (errormsg){
        return res.status(400).json({error: errormsg});
    } 

        var sql1 = `
        UPDATE animal_adoption.animals 
        SET name = ?, 
            age_year = ?, 
            age_month = ?, 
            gender = ?, 
            species_id = ?, 
            breed_id = ?, 
            temperament = ?, 
            adoption_status = ?
        WHERE id = ?
    `;

    var parameter1 = [
        req.body.name,
        req.body.age_year,
        req.body.age_month,
        req.body.gender,
        req.body.species_id,
        req.body.breed_id,
        req.body.temperament,
        req.body.adoption_status,
        req.params.id
    ];

    //Perform database query
    db.query(sql1, parameter1, function(error1, result1){
        if (error1) return res.status(500).json ({error: "Database error updating animal"})

        if (result1.affectedRows === 0) {
            return res.status(404).json({ error: "animal not found" });
        }


        if (req.body.default_image !=1) {
            return res.json(result1);
        }

        var sql2 ="UPDATE animal_adoption.animal_images SET image_url=? WHERE animal_id=? AND is_default =1";
        var parameter2 = [req.body.image_url, req.params.id];

        db.query(sql2, parameter2, function(error2, result2){
            if(error2) {
                return res.status(500).json({ error: "Database error updating default image" });
            }

            if (result2.affectedRows ===0){
                var sql3 = "INSERT INTO animal_adoption.animal_images (animal_id, image_url, is_default) VALUES (?,?,1)";
                var parameter3 = [req.params.id,req.body.image_url];
                
                db.query(sql3,parameter3, function(error3, result3){
                    if (error3) {
                        return res.status(500).json({ error: "Database error inserting default image" });
                    }
                    res.json(result3)
                });
            } else {
                res.json(result2);
            }
         });
    });
});



//animals delete from animal images and animals table
app.route('/animals/:id').delete(function(req,res) {
       var sql = "DELETE FROM animal_adoption.animal_images WHERE animal_id = ?";
       var parameter = [req.params.id];

       db.query(sql, parameter, function (error, result) {
        if (error) {
            return res.status(500).json({ error: "Database error deleting animal images" });
        } else {
            var sql2 = "DELETE FROM animal_adoption.animals WHERE id = ?";
            var parameter2 = [req.params.id];

            db.query(sql2, parameter2, function (error2, result2) {
                if (error2) return res.status(500).json({error: "Database error deleting animal"})
                if (result2.affectedRows ===0){
                    return res.status(404).json({error: "animal not found"})
                }
                return res.json(result2)
            });
        }
    });
});

// GET ALL images for one animal 
app.route ('/animals/:id/images').get(function (req,res) {
    var sql = " SELECT id, animal_id, image_url, is_default FROM  animal_images WHERE animal_id=?";
    var params = [req.params.id];

    db.query (sql,params , function (error,result){
        if (error) return res.status(500).json({ error: "Database error fetching images" });
        res.json(result);
    })
})

// delete ONE image for the animal
app.route ('/animals/:id/images/:imageid').delete(function (req,res) {
    var animalid = req.params.id;
    var imageid = req.params.imageid;

    var checksql = " SELECT is_default FROM  animal_adoption.animal_images WHERE id=? AND animal_id=?"
    db.query(checksql, [imageid,animalid], function(err,rows) {
        if (err) {
            return res.status(500).json({ error: "Database error checking image" });   
        }
        if (rows.length ===0) {
            return res.status(404).json ({ error: "image not found"});
        }

        if (rows[0].is_default ===1) {
            return res.status(400).json({ error: "Cannot delete the default image"})
        }

        var deletesql = "DELETE FROM animal_adoption.animal_images WHERE id=? AND animal_id=?";
        db.query (deletesql, [imageid,animalid], function (error2,result2) {
            if (error2){return res.status(500).json({ error: "Database error deleting image" });
            } 
            res.json(result2)
        })
    })
})

//replace default image for an animal
app.route ('/animals/:id/images/default').put(function (req,res) {
    var animalid = req.params.id;


    // (req.body.image_url || "") means that if image_url exists then use it, else use "" 
    // this is so that if image_url were to be null, it will use "".trim() preventing from crashing
    var newurl = (req.body.image_url || "").trim();

    //checks if URL is empty
    if (!newurl) {
        return res.json({
            error: "image_url is required"
        })
    }

    var findSql = `
        SELECT id FROM animal_adoption.animal_images WHERE animal_id = ? AND is_default = 1`;

    db.query(findSql, [animalid], function (error1, rows) {
        if (error1) {
            return res.status(500).json({ error: "Database error finding default image" });
        }

        if (rows.length > 0) {
            var defaultImageId = rows[0].id;

            var updateSql = `
                UPDATE animal_adoption.animal_images SET image_url = ? WHERE id = ? AND animal_id = ? AND is_default = 1 `;

            return db.query(updateSql, [newurl, defaultImageId, animalid], function (error2, result2) {
                if (error2) {
                    return res.status(500).json({ error: "Database error updating default image" });
                }
                res.json(result2);
            });
        }

        var insertSql = `   
            INSERT INTO animal_adoption.animal_images (animal_id, image_url, is_default) VALUES (?, ?, 1) `;


        db.query(insertSql, [animalid, newurl], function (error3, result3) {
            if (error3) {
                return res.status(500).json({ error: "Database error inserting default image" });
            }
            res.json(result3);
        });
    });
});

//POST non default image route
app.route ('/animals/:id/images').post(function (req,res) {
    var imageurl = req.body.image_url;
    var animalid= req.params.id
    var sql = " INSERT INTO animal_adoption.animal_images (animal_id, image_url, is_default) VALUES (?,?,0)"
    
    var params= [animalid, imageurl]
    db.query (sql,params, function (error,result){
        if (error) return res.status(500).json({ error: "Database error inserting image" });
        res.json(result);
    })
})

//replace image url for one extra image
app.route('/animals/:id/images/:imageid').put(function (req, res) {
    var animalid = req.params.id;
    var imageid = req.params.imageid;
    var imageurl = req.body.image_url;

    var sql1 = "SELECT is_default FROM animal_adoption.animal_images WHERE id=? AND animal_id=?";
    var parameter1 = [imageid, animalid];
    
    db.query(sql1, parameter1, function(error1, result1) {
        if(error1)return res.status(500).json({ error: "Database error checking image" });
        
        if(result1.length === 0) {
            return res.status(404).json({error: "image not found"});
        }

        var sql2 = "UPDATE animal_adoption.animal_images SET image_url=? WHERE id=? AND animal_id=?";
        var parameter2 = [imageurl, imageid, animalid];
        
        db.query(sql2, parameter2, function(error2, result2) {
            if(error2) return res.status(500).json({ error: "Database error updating image" });

            res.json(result2);
        });
    });
});
 
// get all species from the database
// also special feature route
app.route('/species').get(function(req,res){
    var sql = "SELECT species.id, species.name FROM animal_adoption.species ORDER BY species.name";
    db.query(sql, function(error, result){
        if (error) return res.status(500).json({ error: "Database error fetching species" });
        res.json(result);
    });
});

//get all breeds for one species
app.route('/species/:id/breeds').get(function(req,res){
    var sql = `
        SELECT breeds.id, breeds.name
        FROM animal_adoption.breeds
        WHERE breeds.species_id = ?
        ORDER BY breeds.name
    `;
    db.query(sql, [req.params.id], function(error, result){
        if (error) return res.status(500).json({ error: "Database error fetching breeds" });
        res.json(result);
    });
});


// set ONE existing image as default for an animal
app.route('/animals/:id/images/:imageid/default').put(function (req, res) {
    var animalid = req.params.id;
    var imageid = req.params.imageid;

    //Check image exists and belongs to animal
    var checkSql = `
        SELECT id FROM animal_adoption.animal_images 
        WHERE id = ? AND animal_id = ?
    `;

    db.query(checkSql, [imageid, animalid], function (error1, result1) {
        if (error1) {
            return res.status(500).json({ error: "Database error checking image" });
        }

        if (result1.length === 0) {
            return res.status(404).json({ error: "image not found" });
        }

        //Remove default from all images of this animal
        var clearSql = `
            UPDATE animal_adoption.animal_images 
            SET is_default = 0 
            WHERE animal_id = ?
        `;

        db.query(clearSql, [animalid], function (error2, result2) {
            if (error2) {
                return res.status(500).json({ error: "Database error clearing default images" });
            }

            //Set selected image as default
            var setSql = `
                UPDATE animal_adoption.animal_images 
                SET is_default = 1 
                WHERE id = ? AND animal_id = ?
            `;

            db.query(setSql, [imageid, animalid], function (error3, result3) {
                if (error3) {
                    return res.status(500).json({ error: "Database error setting default image" });
                }

                res.json(result3);
            });
        });
    });
});




app.listen(8080 , "127.0.0.1");
console.log("web server running @ http://127.0.0.1:8080");