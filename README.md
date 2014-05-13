meteor-qedit
============

A quick-and-dirty inline field editor with jQuery for Meteor.

## Usage ##
    
### HTML ###

    <span id="editable" data-type="text" data-pk="a23e492b3e432" data-name="value">{{aReactiveField}}</span>
    
### JavaScript ###
  
    // Records = new Meteor.Collection("records");
    
    $("#editable").qedit({
      saveCallback: function(e, value) {
        changes = {};
        changes[this.data.name] = value;
        Records.update(this.data._id, {$set: changes});
      }
    });
