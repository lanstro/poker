var app = app || {};app.ProtagonistHandDescriptionView = Backbone.View.extend({	el: '#protagonist_card_values',	initialize: function(){		this.template= _.template($('#protagonist_card_values_template').html());		this.descriptions={descriptions: ["", "", ""]};		this.listenTo(window.pubSub, "protagonistHandDescriptionsUpdated", this.reaquireDescriptions);	},		reaquireDescriptions: function(descriptions){		this.descriptions={"descriptions": descriptions};		this.render();	},	render: function(){		this.$el.html(this.template(this.descriptions) );		return this;	}	});