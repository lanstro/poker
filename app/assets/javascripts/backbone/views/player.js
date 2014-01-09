var app = app || {};

app.PlayerView = Backbone.View.extend({
	tag: 'div',
	className: 'opponent',
	model: new app.Player(),
	initialize: function(){
		this.template= _.template($('#opponent_template').html());
	},

	render: function(){
		var val = this.model.toJSON();
		this.$el.html( this.template(val));
		return this;
	}
	
});