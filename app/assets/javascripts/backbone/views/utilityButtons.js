var app = app || {};

app.UtilityButtonsView = Backbone.View.extend({
	el: '#utility_buttons',
	initialize: function(){
		this.render();
	},
	events: {
		'click #join': "join",
		'click #leave': "leave",
		'click #sit_out': "sitOut",
		'click #fold': "fold",
		'click #ready': "ready"
	},
	render: function(){
		this.$el.html( $('#utility_buttons_template').html() );
		return this;
	},
	
	join: function(){
		$.getJSON( $('#table').data('table_id')+'/join_table_details', function(data){
			if(!data){
				bootbox.alert("Please login first.");
				return;
			}
			bootbox.prompt("How much would you like to buy in for?\nMinimum buy-in: $"+data.min_table_balance+"\nAvailable balance: $"+data.balance+"\nBalance on other tables: $"+data.table_balance,
				function(result){
					if(!result){
						return;
					}
					result = parseInt(result);
					if(!result){
						bootbox.alert("Please enter a positive number.");
						return;
					}
					else if(result < data.min_table_balance){
						bootbox.alert("That is less than the minimum buy-in for this table.");
						return;
					}
					else if(result > data.balance){
						bootbox.alert("You do not have that amount of money available.");
						return;
					}
					$.ajax({ 
						type: "POST",
						url: $('#table').data('table_id')+'/join',
						data: {amount: result},
					  dataType: "json",
						complete: function(response){
							bootbox.alert(response.responseText);
						}
					});
				}
			);
		});
	},
	leave: function(){
		console.log("pressed");
	},	
	
	sit_out: function(){
	},
	
	fold: function(){
	},
	
	ready: function(){
	},
});