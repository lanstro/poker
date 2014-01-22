var app = app || {};

app.SortButtonsView = Backbone.View.extend({
	el: '#sort_buttons',
	initialize: function(){
		this.render();
	},
	events: {
		'click #sort_by_val': "sortByVal",
		'click #sort_by_suit': "sortBySuit",
		'click #swap_cards': "swapCards"
	},
	render: function(){
		this.$el.html( $('#sort_buttons_template').html() );
		return this;
	},
	
	sortByVal: function(){
		app.pubSub.trigger("sortByVal");
	},
	
	sortBySuit: function(){
		app.pubSub.trigger("sortBySuit");
	},
	
	swapCards: function(){
		app.pubSub.trigger("swapCards");
	}
	
});