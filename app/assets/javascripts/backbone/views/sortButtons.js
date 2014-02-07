var app = app || {};

app.SortButtonsView = Backbone.View.extend({
	el: '#sort_buttons',
	initialize: function(){
		_.bindAll(this, 'render', 'statusChanged');
		this.listenTo(app.playerInfoCollection, "change:protagonist", this.toggleProtagonist);
		
		this.toggleProtagonist();
	},
	
	render: function(){
		var protagonist = app.playerInfoCollection.getProtagonistModel();
		var status = app.statusModel.get('status');
		if(!protagonist)
			this.$el.css({display:"none"});
		else if(status < DISTRIBUTING_CARDS || status >= SHOWDOWN_NOTIFICATION)
			this.$el.css({display:"none"});
		else if(protagonist.get("in_current_hand") && !protagonist.get("folded"))
			this.$el.css({display:"block"});
		else
			this.$el.css({display:"none"});
		return this;
	},

	statusChanged: function(data){
		if(data.get("status") === DISTRIBUTING_CARDS || data.get("status") === SHOWDOWN_NOTIFICATION)
			this.render();
	},
	
	toggleProtagonist: function(arg){
		var protagonist = app.playerInfoCollection.getProtagonistModel();
		if(protagonist){
			this.listenTo(app.statusModel, "change:status", this.statusChanged);
			this.listenTo(app.playerInfoCollection.getProtagonistModel(), "change:folded", this.render);
			this.listenTo(app.playerInfoCollection.getProtagonistModel(), "change:in_current_hand", this.render);
			this.render();
		}
		else{
			this.stopListening();
			this.listenTo(app.playerInfoCollection, "change:protagonist", this.toggleProtagonist);
			this.render();
		}
	},
	
	events: {
		'click #sort_by_val': "sortByVal",
		'click #sort_by_suit': "sortBySuit",
		'click #swap_cards': "swapCards"
	},

	sortByVal: function(){
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN){
			return;
		}
		app.pubSub.trigger("sortByVal");
	},
	
	sortBySuit: function(){
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN){
			return;
		}
		app.pubSub.trigger("sortBySuit");
	},
	
	swapCards: function(){
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN){
			return;
		}
		app.pubSub.trigger("swapCards");
	}
	
});