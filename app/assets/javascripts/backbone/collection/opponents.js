var app = app || {};

app.Opponents = Backbone.Collection.extend({
	model: app.Player,
	initialize: function(){
		this.url=$('#table').data('table_id')+'/players_info';
		this.fetch();
	},
	getProtagonistModel: function(){
		var result=null;
		this.each(function(model){
			if(model.get("protagonist"))
				result= model;
		});
		return result;
	}
});