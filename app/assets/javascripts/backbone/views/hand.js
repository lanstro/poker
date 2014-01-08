var app = app || {};

app.HandView = Backbone.View.extend({
	el: '#protagonist_cards',
	initialize: function(){
		this.collection= new app.Hand();
		for(var i=0;i<5;i++){
			this.addCard();
		}
		this.render();
	},
	
	addCard: function(value){
		this.collection.add(new app.Card());
	},
	render: function(){
		this.$el.empty();
		this.collection.each(function(card){
			this.renderCard(card);
		}, this);
		return this;
	},
	renderCard: function(card){
		var CardView=new app.CardView({
			model:card,
		});
		this.$el.append(CardView.render().$el);
	},
	
});