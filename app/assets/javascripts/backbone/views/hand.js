var app = app || {};

app.HandView = Backbone.View.extend({
	el: '#protagonist_cards',
	initialize: function(){
		var col = new app.Hand();
		this.collection= col;
		
		_.each(col.data, function(value){
			this.addCard(value);
		});

		_.bindAll(this, 'render', 'collectionChanged');
		
		
		this.listenTo(col, "change", this.collectionChanged);
		this.listenTo(col, "sync", this.render);
		this.listenTo(col, "all", this.eventTracker);
	},
	
	eventTracker: function(arg1, arg2){
		console.log("hand view's 'all' event called");
		console.log("event was: "+arg1);
	},
	
	addCard: function(value){
		var newCard= new app.Card();
		this.collection.add(newCard);
		newCard.update(value);
	},
	render: function(){
		console.log("render called");
		this.$el.empty();
		this.collection.each(function(card){
			this.renderCard(card);
		}, this);
		return this;
	},
	renderCard: function(card){
		var cardView=new app.CardView({
			model:card,
		});
		this.$el.append(cardView.render().$el);
	},
	
	collectionChanged: function(changed){
		console.log("hand's changed callback called");
		console.log(changed.toJSON());
	}
	
});