#!/usr/bin/env ruby
#
#--
#  Created by Adam Beguelin on 2007-03-27.
#  Truveo Video Search Ruby API version 3.
#  Copyright (c) 2007. AOL LLC.
#  All rights reserved.
#++

$VERBOSE = 0

require "net/http"
require "uri"
require "rexml/document"
include REXML

=begin rdoc
TruveoResponse objects are returned from Truveo methods get_videos(), get_related_categories(), get_related_channels(),
get_related_tags(), and get_related_users().  For example, the following line of code creates a new TruveoResponse object
as the result of a call to Truveo.get_videos().

  res = t.get_videos("funny")
  
The video_set attribute is an array of the videos returned by the TruveoResponse.get_videos call.

  res.video_set.each{|v| ... } # iterates through the videos, each video is a hash of the metadata for that video
  
The channel_set is a hash of the channels that match the query.  The key is the name of the channel.  The value is
the count of the number of videos in that channel that match the query.

  res.channel_set.each_pair{|key,val| ... }

The tag_set, cateogry_set, and user_set members are similar to the channel_set member described above. 

The TruveoResponse also implements the <tt>each</tt> method which supports iteration through the all the videos that can be returned by the get_videos()
query that created the TruveoResponse, up to 1,000 videos.

  res = t.get_videos("funny")
  res.each{|v| puts v['title']}
    
=end 

class TruveoResponse
  # Array of videos returned by the query. 
  #   res.video_set # <-- array of the videos that matched query
  attr :video_set, true                  
  # Hash of channels and their related counts for your query
  #   res.channel_set # <-- hash of the matching channels
  attr :channel_set, true 
  # Hash of categories and their related counts for your query
  #   res.category_set # <-- hash of the matching categories
  attr :category_set, true
  # Hash of tags and their related counts for your query
  #   res.tag_set # <-- hash of the matching tags
  attr :tag_set, true
  # Hash of users and their related counts for your query
  #   res.user_set # <-- hash of the matching users
  attr :user_set, true
                                        
  # String containing method, i.e., 'truveo.videos.getVideos'
  #   res.method
  attr :method, true
  # String containing the query used to create this response object
  #   res.query
  attr :query, true
  # String containging the sorter used to create this response
  #   res.sortby
  attr :sortby, true
  
  # String containing the query suggestion, if any
  #   res.query_suggestion
  attr :query_suggestion, true          
  # String indicating the number of total results that matched the query
  #   res.total_results_available
  attr :total_results_available, true   
  # String indicating the number of resutls returned in this result set.  For get_videos() the following should be true:  video_set.length == total_resutls_returned.to_i)
  #   res.total_results_returned
  attr :total_results_returned, true    
  # String representing the position of the first Video in the entire set of matching videos.
  #   res.first_result_position
  attr :first_result_position, true     
  # String containing the URL which will return an RSS feed for the set of videos returned in response to the submitted query.
  #   res.rss_url
  attr :rss_url, true                   
  # String containing a human-readable title for the set of videos returned in response to the submitted request. 
  # For example, this field would return a string such as "Most popular 'madonna' videos in Music on MTV" for the query 'madonna category:Music channel:MTV sort:mostPopular'.
  #   res.video_set_title
  attr :video_set_title, true           
  
  # String indicating the number of channel results returned 
  #   res.channel_set.length == res.channel_results_returned.to_i # <-- true
  attr :channel_results_returned, true  
  # String indicating the number of category results returned 
  #   res.category_set.length == res.cagegory_results_returned.to_i # <-- true
  attr :category_results_returned, true 
  # String indicating the number of tag results returned 
  #   res.tag_set.length == res.tag_results_returned.to_i # <-- true
  attr :tag_results_returned, true      
  # String indicating the number of user results returned
  #   res.user_set.length == res.user_results_returned.to_i # <-- true
  attr :user_results_returned, true     
      
  # String indicating the integer code for the error if one occured    
  attr :error_code, true                
  # String containing text of error code if one occured.
  attr :error_text, true                

  # :stopdoc:  
  
  def initialize
    @vidlist = Array.new
  end
  
  attr :sphinxquery, true               # sqphinx query used
  attr :sphinxfilters, true             # sqphinx filters used
  
  attr :params, true                    # parameters sent to truveo api call when TruveoResponse was created
  attr :truveo, true                    # truveo object used to create the results, used for next_video

  # copy over state for next_video call  
  def next_self(res)
    self.video_set = res.video_set
    self.channel_set = res.channel_set
    self.category_set = res.category_set
    self.tag_set = res.tag_set
    self.user_set = res.user_set

    self.query_suggestion = res.query_suggestion
    self.total_results_available = res.total_results_available
    self.total_results_returned = res.total_results_returned
    self.first_result_position = res.first_result_position
    self.rss_url = res.rss_url
    self.video_set_title = res.video_set_title

    self.channel_results_returned = res.channel_results_returned
    self.category_results_returned = res.category_results_returned
    self.tag_results_returned = res.tag_results_returned
    self.user_results_returned = res.user_results_returned

    self.sphinxquery = res.sphinxquery
    self.sphinxfilters = res.sphinxfilters
  end

# :startdoc:

=begin rdoc

Iterate through all the videos in the response.  Each video is a hash where the key is the metadata field, like title, 
and the value is the actual metadata.  The videos are returned in whatever order was specified by the sorter, if any,
used in the query that created the TruveoResponse object.

The following goes through all the videos that match the query and prints the title.  If more than one thousand
videos match the query, the each method will only iterate through the first thousand.

  # create a Truveo object with my app id (apply for a free app id at http://developer.truveo.com/)
  t = Truveo.new("appid")
  res = t.get_videos("funny")
  
  # print lots of titles
  res.each{|vid| puts vid['title']}

Note that the each method will invoke another get_videos() method behind the scenes.  These calls will count against your
daily limit.  This means iterating through a thousand results using <tt>each</tt> will result in 100 calls to <tt>get_videos()</tt>
by default.

=end rdoc

  def each #  :yields: video
    # if we've stored the results so fare
    @vidlist.each { |v| yield v }
    # get any more videos, storing the results for later calls to self.each
    while v = next_video do
      @vidlist << v
      yield v
    end
  end
  
# :stopdoc:
  
  # get the next video, assumes a query has already been made, @video_set, @params, and @next_start have been set in get_videos_hash()
  def next_video
    return nil if video_set.nil?

    # get more video if video_set has been depleted
    if video_set.length  < 1
      next_start = first_result_position.to_i + total_results_returned.to_i      
      # check for valid start, we never return more than 1000 results
      return nil if next_start >= 1000
      # try to get another video_set
      self.params[:start] = next_start.to_s
      res = truveo.get_videos_hash(params)
      next_self(res)
      return nil if video_set.nil? || video_set.length < 1
    end

    video_set.shift
  end
# :startdoc:
      
end

=begin rdoc

The Truveo class implements a Ruby version of the Truveo API (see the {Truveo Developer Site}[http://developer.truveo.com] for details).  
A Truveo object is initialized with an developer id, which is free and can be obtained from 
the {Truveo Developer Site}[http://developer.truveo.com].  A developer id will allow you to call the Truveo API 
up to 10,000 times per day.

Currently user functions, like ratings, are not implemented in the Ruby API.

=end

class Truveo

  @@sorter = %w(sort:mostPopular sort:mostPopularNow sort:mostPopularThisWeek sort:mostPopularThisMonth sort:vrank sort:mostRecent sort:mostRelevant sort:topFavorites sort:highestRated)
  @@filter = %w(days_old: bitrate: type:free type:reg type:sub type:rent type:buy runtime: quality:poor quality:fair quality:good quality:excellent format:win format:real format:qt format:flash format:hi-q site: file_size:) # XXXX add these, should there be two types?  One that takes a comparison and one that doesn't?
  @@modifier = %w(category: channel: tag: user: id: sim: title: description: artist: album: show: actor: director: writer: producer: distributor:)

  # array of Truveo supported sorters such as <tt>sort:vrank</tt>
  #
  # Example:
  #   Truveo.sorter.each{|s| puts s } # print all the sorters
  #
  def Truveo.sorter
    @@sorter
  end

  # array of Truveo supported filters such as <tt>type:free</tt>
  #
  # Example:
  #   Truveo.filter.each{|f| puts f } # print all the filters
  #
  def Truveo.filter
    @@filter
  end
  
  # array of Truveo supported modifiers such as <tt>tag:</tt>
  # 
  # Example:
  #   Truveo.modifier.each{|m| puts m } # print all the modifiers
  #
  def Truveo.modifier
    @@modifier
  end
  
  # Create a new Truveo object for querying the Truveo video search engine.
  # The appid is required.  For your free appid go to {My API Account}[http://developer.searchvideo.com/APIMyAccount.php]
  # where you easily sign up for your own appid, allowing you up to 10,000 Truveo queries per day.
  # :call-seq: new(appid)
  #
  # Example:
  #     t = Truveo.new('my_appid')  # create a new Truveo object with your app_id
  #
  def initialize(appid, site = 'xml.searchvideo.com', path = "/apiv3?", port=80)
    @appid = appid 
    @site = site
    @path = path
    @port = port
  end

  # generic rest call
  def rest(parms) # :nodoc:
    call = String.new(@path)
    parms.each{|k,v| call << "#{k}=#{v}&"}
    call.chop! 
    call = URI.escape(call)
    api_site = Net::HTTP.new(@site,@port)
    # puts call
    xml = REXML::Document.new(body = api_site.request_get(call).body)
    return xml
  rescue REXML::ParseException => e
    puts "rest parse rescue: " # + e.to_s
    puts "zzz>>> #{body}<<<zzz"
    return nil
  rescue Exception => e
    puts "rest rescue: " + e.to_s.split("\n")[0]
    pp e
    puts "site, path, parms: #{@site}, #{@path}, :#{call}:"
    return nil
  end

  # return the error as hash or nil if no error
  def api_error(xml) #:nodoc:
    if xml.nil?
      res = TruveoResponse.new
      res.error_code = '69'
      res.error_text = 'bad xml'
      return res
    end
    #<?xml version='1.0' encoding='UTF-8'?><Response><Error Code='14'>Access Denied: invalid appid.</Error></Response>
    if elt = xml.elements['//Error']
      res = TruveoResponse.new
      res.error_code = elt.attributes["Code"]
      res.error_text = elt.text
      return res
    end
    nil
  end
  
  # convert an xml element to a string
  def elt_text(xml,s) #:nodoc:
    if elt = xml.elements[s]
      return elt.text
    end
    return nil
  end
  
  # convert xml to hash  
  def xml_to_hash(xml) #:nodoc:
    h = Hash.new
    xml.elements.each{|e| h[e.name] = e.text }
    h 
  end
  
  # performs the specified query and returns the results in the form of a TruveoResponse object.
  # query:: this is the search query to run.  See {Building Search Queries}[http://developer.truveo.com/SearchQueryOverview.php] for details.
  # results:: number of results to return, the default is 10, the maximum is 50.
  # start:: where to start the result set being returned,  defaults to 0.  Can be used to page through results.
  # showRelatedItems:: indicates if the tag set, category set, and user set should be returned.  Values should be 0 or 1, the default is 0.
  # tagResults:: number of tags requested in the tag_set response.  
  # channelResults:: number of channels requested in the channel_set response.
  # categoryResults:: number of categories requested in the category_set response.
  # userResults:: number of users requested in the user_set response.
  # showAdult:: flag indicating whether or not adult content should be included in the result set.
  # All of the result sizes above are maximums.  A query may return fewer than the requested number of results if the requested  
  # number of results don't match.
  #       
  # If the query string is empty, then the top results are returned in vrank order.
  #    
  # If showRelatedItems is zero, the response will only includea a video_set.  The tag_set, channel_set, category_set, and user_set
  # parameters will be left out.
  
  def get_videos(query='', results=10, start=0, showRelatedItems=0, tagResults=10, channelResults=10, categoryResults=10, userResults=10, showAdult=0)
    params = Hash.new
    params[:method] = 'truveo.videos.getVideos'
    params[:query] = query    
    params[:showRelatedItems] = showRelatedItems
    params[:tagResults] = tagResults
    params[:channelResults] = channelResults
    params[:categoryResults] = categoryResults
    params[:userResults] = userResults
    params[:showAdult] = showAdult
    params[:appid]  = @appid              
    params[:results] = results
    params[:start] = start

    get_videos_hash(params)
  
  end
  
  def get_videos_hash(params) #:nodoc:


    xml = rest(params)
    
    res = TruveoResponse.new
    
    # save params for next_video call
    res.params = params
    res.truveo = self
    
    # check for error codes
    err = api_error(xml)
    puts "get_videos(#{params[:query]}) returned error: #{err.error_code} #{err.error_text}" if $VERBOSE && !err.nil?
    return err if !err.nil?

    res.method = elt_text(xml,'//Response/method')
    res.query = elt_text(xml,'//Response/query')
    res.sortby = elt_text(xml,'//Response/sortby')
    res.query_suggestion = elt_text(xml,'//Response/querySuggestion')   
    
    res.total_results_available = elt_text(xml, '//VideoSet/totalResultsAvailable')
    res.total_results_returned = elt_text(xml, '//VideoSet/totalResultsReturned')    
    res.first_result_position = elt_text(xml, '//VideoSet/firstResultPosition')        

    res.rss_url = elt_text(xml, '//rssUrl')        
    res.video_set_title = elt_text(xml, '//VideoSet/title')        
    
    res.sphinxquery = elt_text(xml,'//Response/sphinxquery')
    res.sphinxfilters = elt_text(xml,'//Response/sphinxfilters')    
         
    # store the video set
    res.video_set = Array.new
    @video_set = Array.new
    xml.elements.each('//Video') {|v| 
      res.video_set << (tvid = xml_to_hash(v))
      @video_set << tvid      
    }
    
    @next_start = res.total_results_returned.to_i + res.first_result_position.to_i
    
    if res.total_results_returned.to_i != res.video_set.length
      puts "Warning: results mismatch: res.total_results_returned (#{res.total_results_returned}) != res.video_set.length (#{res.video_set.length})"
      # puts xml.to_s
    end
    
    # the channel_set is a hash, one entry per channel.  the key is the channel name, the value is the count.
    res.channel_results_returned = elt_text(xml, '//ChannelSet/totalResultsReturned')        
    res.channel_set = set_hash(xml,'//Channel')
    
    res.tag_results_returned = elt_text(xml, '//TagSet/totalResultsReturned')            
    res.tag_set = set_hash(xml,'//Tag')
    
    res.category_results_returned = elt_text(xml, '//CategorySet/totalResultsReturned')            
    res.category_set = set_hash(xml, '//Category')
    
    res.user_results_returned = elt_text(xml, '//UserSet/totalResultsReturned')            
    res.user_set = set_hash(xml, '//User')
    
    res
    
  end
  
  # return the hash for the given set (category, channel, tag, or user)
  def set_hash(xml,s) #:nodoc:
    h = Hash.new
    xml.elements.each(s){|v| h[v.elements['name'].text] = v.elements['count'].text.to_i}   
    h
  end
  

  # generic get_related for each of the get_related type calls
  def get_related(type='Tags', query='', results=10, start=0) #:nodoc:

    params = Hash.new
    params[:method] = "truveo.videos.getRelated#{type}"
    params[:query] = query    
    params[:appid]  = @appid              
    params[:results] = results
    params[:start] = start    

    xml = rest(params)
    
    res = TruveoResponse.new
    
    # check for error codes
    err = api_error(xml)
    return err if !err.nil?

    res.method = elt_text(xml,'//Response/method')
    res.query = elt_text(xml,'//Response/query')
    res.sortby = elt_text(xml,'//Response/sortby')
    res.query_suggestion = elt_text(xml,'//Response/querySuggestion')   
    
    res.sphinxquery = elt_text(xml,'//Response/sphinxquery')
    res.sphinxfilters = elt_text(xml,'//Response/sphinxfilters')
    
    res.total_results_returned = elt_text(xml, '//totalResultsReturned')    
    res.first_result_position = elt_text(xml, '//firstResultPosition')       
     
    res.send("#{singularize(type).downcase}_set=", set_hash(xml,"//#{singularize(type)}"))
    
    res
    
  end

  # Return a hash of the tags and counts related to the query.
  #  
  # The results and start parameters are used for paging through the result set.
  #
  # Example:
  #   t = Truveo.new('appid_goes_here')
  #   res = t.get_related_tags('funny')
  #   res.tag_set.each_pair{|k,v| puts "tag: #{k} count: #{v}" }
  def get_related_tags(query='', results=10, start=0)
    get_related('Tags', query, results, start)
  end
  
  # Return a hash of the channels and counts related to the query.
  #
  # The results and start parameters are used for paging through the result set.
  def get_related_channels(query='', results=10, start=0)
    get_related('Channels',query, results, start)
  end
  
  # Return a hash of the users and counts related to the query.
  #
  # The results and start parameters are used for paging through the result set.
  def get_related_users(query='', results=10, start=0)
    get_related('Users',query, results, start)
  end
  
  # Return a hash of the categories and counts related to the query.
  #
  # The results and start parameters are used for paging through the result set.
  def get_related_categories(query='', results=10, start=0)
    get_related('Categories',query, results, start)
  end

  def singularize(s) #:nodoc:
    return s.chop if s =~ /(Tags|Channels|Users)/
    return 'Category' if s =~ /Categories/
    return s
  end
  
  private :singularize
  
end
