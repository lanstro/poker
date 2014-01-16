var app = app || {};

app.CardView = Backbone.View.extend({
	tag: 'div',
	className: 'protagonist_card',
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
		if(this.model.get("human_description") == "blank"){
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
		if(this.isBlank()){
			if( $(".highlighted").length ===0 ){
				// do nothing
				console.log("nothing to push");
			}
			else {
				window.pubSub.trigger("blankClicked", this.model.get("row"), this.model.get("position"));
			}
		}
		else{
			
			this.model.toggleHighlighted();
		}
	},
	
	swapPosition: function(otherCard){
		
	},

	render: function(){
	  var val = this.model.toJSON();
		this.$el.html(this.template(val));
		return this;
	}
	
});