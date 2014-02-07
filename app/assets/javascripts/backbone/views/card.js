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
		_.bindAll(this, 'dragStarted', 'droppedOn');
		this.template=_.template($('#card_template').html());
		this.listenTo(this.model, "change:highlighted", this.filterHighlighted);
	},
	
	events: {
		'click': 'toggleHighlight',
		'dragstart': 'dragStarted',
		'drop': 'droppedOn',
		'dragenter': 'dragEntered',
		'dragleave': 'dragLeft',
		'dragover': 'draggedOver',
		'dragend': 'dragEnded'
	},
	
	dragStarted: function(arg){
		if(this.isBlank()){
			arg.preventDefault();
			return;
		}
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
		this.model.set("highlighted", true);
		console.log(arg);
		arg.originalEvent.dataTransfer.setData('text/html', this.model.get("val"));
		
	},
	
	draggedOver: function(e) {
		e.preventDefault(); 
		return false;
	},
	
	dragEnded: function(e){
		e.stopPropagation();
		e.preventDefault();
		return false;
	},
	
	droppedOn: function(arg){
		var data = arg.originalEvent.dataTransfer.getData('text/html');
		console.log(this.model);
		console.log(data);
		arg.stopPropagation(); // stops the browser from redirecting.
		arg.preventDefault();
		app.pubSub.trigger("dragDropFinished", data, this.model);
		if(data["val"] == this.model.get("val"))
			return;
	},
	
	dragEntered: function(arg){
		arg.preventDefault();
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
		this.$el.children(":first").addClass("drag_highlighted");
	},
	
	dragLeft: function(arg){
		if(app.statusModel.get("status") < DEALING || app.statusModel.get("status") > ALMOST_SHOWDOWN)
			return;
		this.$el.children(":first").removeClass("drag_highlighted");
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
		if(this.model.get("highlighted"))
			this.$el.children(":first").addClass("highlighted");
		return this;
	}
	
});