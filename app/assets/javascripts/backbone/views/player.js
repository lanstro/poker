var app = app || {};

app.PlayerView = Backbone.View.extend({
	tag: 'div',
	className: 'opponent',
	model: new app.Player(),
	initialize: function(){
		_.templateSettings = {
			interpolate: /\<\@\=(.+?)\@\>/gim,
			evaluate: 	 /\<\@(.+?)\@\>/gim,
			escape: 		 /\<\@\-(.+?)\@\>/gim
		};
		this.template= _.template($('#opponent_template').html());
		this.handView= new app.SortedSubHandView({
			model: this.model
		});
	},

	render: function(){
		var val = this.model.toJSON();
		this.$el.html( this.template(val));
		this.$el.append(this.handView.render().$el);
		return this;
	}
	
});