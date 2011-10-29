This is a script to handle pulling recent activity on Github (eg, from a user's
public atom feed) into a MySQL database, where the data can be used for 
nefarious purposes such as displaying said data on your website about your cat.

The script pulls the following data:

	- Activity Title
	- Activity Time
	- Limited Activity Content

That's all it does.  Activity Content is limited to anything returned in the
atom feed's 'content' block that's surrounded by blockquote tags.  This allows
for additional useful data to be made available, without the horrors of
the atom feed's more broken components - useless cruft, links without a
domain reference, allusions to 'Someone' committing, et cetera.
