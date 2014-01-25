var app = app || {};

app.CardView = Backbone.View.extend({
	tag: 'div',
	className: 'card',
	initialize: function(){
		_.templateSettings = {
			interpolate: /\<\@\=(.+?)\@\>/gim,
			evaluate: 	 /\<\@(.+?)\@\>/gim,
			escape: 		 /\<\@\-(.+?)\@\>/gim
		};
		this.template=_.template($('#card_template').html());
		this.listenTo(this.model, "all", this.filterHighlighted);
	},
	
	events: {
		'click': 'toggleHighlight'
	},
	
	isBlank: function(){
		if(this.model.get("human_description") === "blank"){
			return true;
		}
		return false;
	},
	
	filterHighlighted: function(arg){
		if(arg=="change:highlighted"){
			this.$el.children(":first").toggleClass("highlighted");
		}
	},
	
	toggleHighlight: function(obj){
	
		if(app.status() < DEALING || app.status() > ALMOST_SHOWDOWN){
			return;
		}
	
		if(this.isBlank()){
			if( $(".highlighted").length > 0 ){
				app.pubSub.trigger("blankClicked", this.model.get("row"), this.model.get("position"));
			}
		}
		else{
			this.toggleHighlighted();
		}
	},
	
	swapPosition: function(otherCard){
		
	},
	
	toggleHighlighted: function(){
		if(this.model.get('highlighted')){
			this.model.set('highlighted', false);
		}
		else{
			this.model.set('highlighted', true);
		}
	},

	render: function(){
	  var val = this.model.toJSON();
		this.$el.html(this.template(val));
		return this;
	}
	
});