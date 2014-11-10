class Profile < ActiveRecord::Base

  require 'rubygems'
  require 'net/ldap'

  has_many :jobs
  has_many :payments

  @@per_page = 10

  # email Validation
  validates_format_of :email,
                      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/,
                      :message => 'is no valid email address'

  def self.authenticate_me(account, password)

    if (account == "") || (password == "")
      return false
    end

    logged_in = false

    # Demo Account
    # Account and Password == "demo"

    if (account == "demo") && (password = "demo") && (ENV['USER_DEMO_ENABLED'] == "true")
      # Search User in DB
      if myprofile = Profile.find_by_ldap_account(account)
        return myprofile
        #User is in DB
      else
        # Add User to DB
        myprofile = Profile.new
        myprofile.ldap_account= account
        # Give User the lowest Status
        myprofile.status= 'demo'
        myprofile.name= 'Demo Account'
        myprofile.email= 'demo@demo.demo'
        # Save Profile
        myprofile.save
        return myprofile

      end

    elsif (account == "admin") && (password == ENV['USER_ADMIN_PW'])
      # Search User in DB
      if myprofile = Profile.find_by_ldap_account
        return myprofile
        # User is logged in but not in DB
      else
        # Add User in DB
        myprofile = Profile.new
        myprofile.ldap_account= account
        # Give lowest Status
        myprofile.status= 'admin'
        myprofile.name= 'Admin Account'
        # User LDAP TreeBase as Domain Name
        ldap_domain = ENV['LDAP_TREEBASE'].gsub('dc=', '').split(',')
        myprofile.email= 'admin@'+ldap_domain[1]+'.'+ldap_domain[2]
        # Save Profile
        myprofile.save
        return myprofile
      end

    else
      # LDAP Look UP
      ldap = Net::LDAP.new    :host => ENV['LDAP_HOST'],
                              :port => ENV['LDAP_PORT'],
                              :encryption => :simple_tls,
                              :base => ENV['LDAP_TREEBASE'],
                              :auth => {
                                  :method => :simple,
                                  :username => account+'@'+ldap_domain[0]+'.'+ldap_domain[1]+'.'+ldap_domain[2]
                              }

      if ldap.bind
        # Authentication Succeeded
        # Search User in DB
        # User is there and Logged in
        if myprofile = Profile.find_by_ldap_account (account)
          return myprofile
          # User is Logged in but not in DB
        else
          # Add User to DB
          myprofile = Profile.new
          myprofile.ldap_account= account
          # Give User lowest Status
          status_arr = ENV['USER_STATUS'].split(',')
          myprofile.status= status_arr[0]
          # Get User Info from LDAP
          filter = Net::LDAP::Filter.eq(ENV['LDAP_FILTER'], account)
          attrs = ENV['LDAP_ATTRS'].split(",")
          ldap.search(:base => ENV['LDAP_TREEBASE'], :filter => filter, :attributes => attrs, :return_result => false ) do |entry|
            # Save User info in DB
            myprofile.name= entry.sAMAccountName.to_s
            if attrs.include? 'mail'
              myprofile.email= entry.mail.to_s
            elsif attrs.include? 'mailLocalAddress'
              myprofile.email= entry.mailLocalAddress.to_s
            end
          end
          # Save Profile
          myprofile.save
          return myprofile
        end
      else
        # Authentication Failed
        return false
      end

    end

  end

end
