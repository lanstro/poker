var app = app || {};

app.SortedSubHandView = Backbone.View.extend({

	tag: 'div',
	className: 'opponent_cards',

	initialize: function(){
		_.bindAll(this, 'render');

	},
	

});