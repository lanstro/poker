var app = app || {};

app.Player = Backbone.Model.extend ({
	idAttribute: 'seat',
	
	// temp function: remove once reorder how protagonist_cards work
	cards: function(){
		var arrangement = this.get("arrangement");
		var result = [];
		_.each(arrangement, function(row){
			result = result.concat(row.cards);
		});
		return result;
	},
});