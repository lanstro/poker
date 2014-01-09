var app = app || {};

app.Player = Backbone.Model.extend ({

	initialize: function() {
		this.set('avatar', Math.floor(Math.random()*9)+1);
		this.set('balance', 2000);
		this.set('name', "placeholder");
	}

});