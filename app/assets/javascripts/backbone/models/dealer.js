var app = app || {};

app.Dealer = Backbone.Model.extend ({
	initialize: function(){
		this.url=$("#table").data("table_id")+'/status';
		this.fetch();
	}
});