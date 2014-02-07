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
		this.listenTo(this.model, "change:highlighted", this.filterHighlighted);
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
		this.$el.children(":first").toggleClass("highlighted");
	},
	
	toggleHighlight: function(obj){
	
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
	
		if(this.isBlank()){
			if( $(".highlighted").length > 0 ){
				app.pubSub.trigger("blankClicked", this.model.get("row"), this.model.get("position"));
			}
		}
		else{
			this.toggleHighlighted();
		}
	},
	
	toggleHighlighted: function(){
		this.model.set('highlighted', !this.model.get('highlighted'));
	},

	render: function(){
		this.$el.html(this.template({human_description: this.model.get("human_description")}));
		return this;
	}
	
});