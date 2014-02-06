var app = app || {};

app.Player = Backbone.Model.extend ({
	idAttribute: 'seat',
	
	cards: function(){
		var arrangement = this.get("arrangement");
		if(arrangement){
			var result = [];
			_.each(arrangement, function(row){
				result = result.concat(row.cards);
			});
			return result;
		}
		return null;
	},
});