var app = app || {};

app.CardView = Backbone.View.extend({
	tag: 'div',
	className: 'protagonist_card',
	model: new app.Card(),

	render: function(){
	  var val = this.model.JSON_value();
		this.$el.html( "<img src= '/assets/cards/"+val["value_string"]+".png'  >");
		return this;
	}
	
});