var app = app || {};

app.CardView = Backbone.View.extend({
	tag: 'div',
	className: 'protagonist_card',
	model: new app.Card(),
	initialize: function(){
		this.template=_.template($('#card_template').html());
	},

	render: function(){
	  var val = this.model.toJSON();
		this.$el.html(this.template(val));
		return this;
	}
	
});