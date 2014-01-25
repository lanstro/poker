var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	model: new app.Dealer(),
	initialize: function(){
		this.model.url =$("#table").data("table_id")+'/status';
		this.model.fetch();
		
		_.bindAll(this, 'receivedBroadcast');
		this.listenTo(this.model, "all", this.watchBroadcast);
		this.listenToOnce(this.model, "sync", this.broadcastStatusChange);
		this.setupDispatcher();
	},
	
	watchBroadcast: function(arg1, arg2){
		if(arg1 == "change:broadcast"){
			this.render();
		}
	},
	render: function(){
		this.$el.html("<p>"+this.model.get("broadcast")+"</p>");
		return this;
	},
	
	setupDispatcher: function(){
		if(!app.dispatcher){
			app.dispatcher = app.dispatcher || new WebSocketRails($('#table').data('uri'));
			app.dispatcher = app.dispatcher.subscribe($("#table").data("table_id")+'_chat');
		}
		app.dispatcher.bind('client_send_message', this.receivedChat);
		app.dispatcher.bind('table_announcement', this.receivedBroadcast);
		app.dispatcher.bind('hand_dealt', this.handDealt);
	},
	
	receivedChat: function(data){
		app.pubSub.trigger("messageReceived", data);
	},
	
	broadcastStatusChange: function(){
		app.pubSub.trigger("statusChanged",this.model.get("status"));
	},
	
	receivedBroadcast: function(data){
		var oldStatus = this.model.get("status");
		this.model.set({status: data.status, broadcast: data.broadcast});
	  app.pubSub.trigger("messageReceived", data);
		if (oldStatus !== data.status){
			this.broadcastStatusChange(data.status);
			if(oldStatus < INVALIDS_NOTIFICATION && data.status >= INVALIDS_NOTIFICATION){
			  app.pubSub.trigger('arrangements');
			}
		}
	},
	
	handDealt: function(cards){
		app.pubSub.trigger('handDealt', cards);
	},

});