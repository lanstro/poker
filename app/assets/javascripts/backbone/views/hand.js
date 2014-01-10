var app = app || {};

app.HandView = Backbone.View.extend({
	el: '#protagonist_cards',
	initialize: function(){
		var col = new app.Hand();
		this.collection= col;
		col.update();
		
		_.each(this.collection.data, function(value){
			this.addCard(value);
		});

		_.bindAll(this, 'render');
		
		this.collection.on("protagonist_cards:updated", this.render);
		
	},
	
	addCard: function(value){
		var newCard= new app.Card();
		this.collection.add(newCard);
		newCard.update(value);
	},
	render: function(){
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
	}
	
});