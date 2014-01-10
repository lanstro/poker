var app = app || {};

app.Player = Backbone.Model.extend ({
	
	update: function(info){
		this.set('avatar', info.avatar);
		this.set('balance', info.balance);
		this.set('name', info.name);
	}

});