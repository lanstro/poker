var app = app || {};

app.UtilityButtonsView = Backbone.View.extend({
	el: '#utility_buttons',
	initialize: function(){
		this.render();
	},
	events: {
		'click #join_leave': "joinLeave",
		'click #sit_out': "sitOut",
		'click #fold': "fold",
		'click #ready': "ready"
	},
	render: function(){
		this.$el.html( $('#utility_buttons_template').html() );
		return this;
	},
	
	joinLeave: function(){
	},
	
	
	sit_out: function(){
	},
	
	fold: function(){
	},
	
	ready: function(){
	},
});