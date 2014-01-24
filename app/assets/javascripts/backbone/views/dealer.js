var app = app || {};

app.DealerView = Backbone.View.extend({
	el: '#announcements',
	model: new app.Dealer(),
	initialize: function(){
		this.model.url =$("#table").data("table_id")+'/status';
		this.model.fetch();
		
		_.bindAll(this, 'receivedBroadcast');
		this.listenTo(this.model, "all", this.watchBroadcast);
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
		app.dispatcher.bind('gather_hands', this.gatherHands);
		app.dispatcher.bind('arrangements', this.receivedArrangements);
	},
	
	receivedChat: function(data){
		app.pubSub.trigger("messageReceived", data);
	},
	
	receivedBroadcast: function(data){
		this.model.set({status: data.status, broadcast: data.broadcast});
	  app.pubSub.trigger("messageReceived", data);
		app.pubSub.trigger("statusChanged", data.status);
	},
	
	handDealt: function(cards){
		console.log("broadcast hand dealt");
		app.pubSub.trigger('handDealt', cards);
	},
	
	gatherHands: function(){
		app.pubSub.trigger('gatherHands');
	},
	
	receivedArrangements: function(data){
		console.log("received card arrangements");
		this.arrangement=data;
	}
	
});