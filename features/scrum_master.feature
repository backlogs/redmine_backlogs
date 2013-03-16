Feature: Scrum Master
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date  |
        | Sprint 001 | 2010-01-01        | 2010-01-31      |
        | Sprint 002 | 2010-02-01        | 2010-02-28      |
        | Sprint 003 | 2010-03-01        | 2010-03-31      |
        | Sprint 004 | 2 weeks ago       | next week       |
      And I have defined the following stories in the product backlog:
        | subject |
        | Story 1 |
        | Story 2 |
        | Story 3 |
        | Story 4 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story A | Sprint 001 |
        | Story B | Sprint 001 |
      And I have defined the following impediments:
        | subject      | sprint     | blocks  |
        | Impediment 1 | Sprint 001 | Story A | 

  Scenario: Create an impediment
    Given I am viewing the taskboard for Sprint 001
      And I want to create an impediment for Sprint 001
      And I want to set the subject of the impediment to Bad Impediment
      And I want to indicate that the impediment blocks Story B
     When I create the impediment
     Then the request should complete successfully
      And the sprint named Sprint 001 should have 2 impediments named Bad Impediment and Impediment 1

  Scenario: Update an impediment
    Given I am viewing the taskboard for Sprint 001
      And I want to edit the impediment named Impediment 1
      And I want to set the subject of the impediment to Good Impediment
      And I want to indicate that the impediment blocks Story B
     When I update the impediment
     Then the request should complete successfully
      And the sprint named Sprint 001 should have 1 impediment named Good Impediment

  Scenario: View impediments
    Given I am viewing the issues sidebar for Sprint 001
     Then the request should complete successfully
     When I follow "Impediments"
     Then the request should complete successfully
      And I should see "Impediment 1"

  Scenario: Create a new sprint
    Given I am viewing the master backlog
      And I want to create a sprint
      And I want to set the name of the sprint to sprint 005
      And I want to set the sprint_start_date of the sprint to 2010-03-01
      And I want to set the effective_date of the sprint to 2010-03-20
     When I create the sprint
     Then the request should complete successfully
      And I should see "sprint 005"
      And the sprint "sprint 005" should not be shared

  Scenario: Create a new sprint with auto-sharing
    Given I am viewing the master backlog
      And sharing is enabled
      And default sharing for new sprints is hierarchy
      And I want to create a sprint
      And I want to set the name of the sprint to sprint 006
      And I want to set the sprint_start_date of the sprint to 2010-03-01
      And I want to set the effective_date of the sprint to 2010-03-20
     When I create the sprint
     Then the request should complete successfully
      And I should see "sprint 006"
      And the sprint "sprint 006" should be shared by hierarchy

  Scenario: Update sprint details
    Given I am viewing the master backlog
      And I want to edit the sprint named Sprint 001
      And I want to set the name of the sprint to sprint xxx
      And I want to set the sprint_start_date of the sprint to 2010-03-01
      And I want to set the effective_date of the sprint to 2010-03-20
     When I update the sprint
     Then the request should complete successfully
      And the sprint should be updated accordingly

  @javascript
  Scenario: Bug #855 update sprint details must not change project of sprint
    Given the subproject1 project has the backlogs plugin enabled
      And sharing is enabled
      And I am a scrum master of all projects
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | project_id   | sharing     |
        | Shared | 2010-01-01        | 2010-01-31     | ecookbook    | descendants |
      And I have selected the subproject1 project
    Given I am viewing the master backlog
     When I change the sprint name of "Shared" to "sprint xxx"
     Then the sprint "sprint xxx" should be in project "ecookbook"

  Scenario: Update sprint with no name
    Given I am viewing the master backlog
      And I want to edit the sprint named Sprint 001
      And I want to set the name of the sprint to an empty string
     When I update the sprint
     Then the server should return an update error

  Scenario: Move a story from product backlog to sprint backlog
    Given I am viewing the master backlog
     When I move the story named Story 1 to the 1st position of the sprint named Sprint 001
     Then the request should complete successfully
     When I move the story named Story 4 to the 2nd position of the sprint named Sprint 001
      And I move the story named Story 2 to the 1st position of the sprint named Sprint 002
      And I move the story named Story 4 to the 1st position of the sprint named Sprint 001
     Then Story 4 should be in the 1st position of the sprint named Sprint 001
      And Story 1 should be in the 2nd position of the sprint named Sprint 001
      And Story 2 should be in the 1st position of the sprint named Sprint 002
  
  Scenario: Move a story down in a sprint
    Given I am viewing the master backlog
     When I move the story named Story B above Story A
     Then the request should complete successfully
      And Story A should be in the 2nd position of the sprint named Sprint 001
      And Story B should be the higher item of Story A

  Scenario: Authorized request to the project calendar feed
    Given I move the story named Story 4 to the 1st position of the sprint named Sprint 004
      And I have set my API access key
      And I am logged out
     When I try to download the calendar feed
     Then the request should complete successfully
      And calendar feed download should succeed

  Scenario: Unauthorized request to the project calendar feed
    Given I move the story named Story 4 to the 1st position of the sprint named Sprint 004
      And I have set my API access key
      And I am logged out
      And I have guessed an API access key
     When I try to download the calendar feed
     Then the request should fail
      And calendar feed download should fail

  Scenario: Download printable cards for the product backlog
      And I am viewing the issues sidebar
     When I follow "Product backlog cards"
     Then the request should complete successfully

  Scenario: Download printable cards for the task board
      And I move the story named Story 4 to the 1st position of the sprint named Sprint 001
      And I am viewing the issues sidebar for Sprint 001
     When I follow "Sprint cards"
     Then the request should complete successfully

  Scenario: view the sprint notes
    Given I have set the content for wiki page Sprint Template to Sprint Template
      And I have made Sprint Template the template page for sprint notes
      And I am viewing the taskboard for Sprint 001
     When I view the sprint notes
     Then the request should complete successfully
    Then the wiki page Sprint 001 should contain Sprint Template

  Scenario: edit the sprint notes
    Given I have set the content for wiki page Sprint Template to Sprint Template
      And I have made Sprint Template the template page for sprint notes
      And I am viewing the taskboard for Sprint 001
     When I edit the sprint notes
     Then the request should complete successfully
     Then the wiki page Sprint 001 should contain Sprint Template

  @javascript
  Scenario: click the various links to the sprint wiki page and inspect the frontend visually
    Given I have set the content for wiki page Sprint Template to Sprint Template
      And I have made Sprint Template the template page for sprint notes
      And I am viewing the issues list
     #check wiki link from sidebar
     When I follow "Sprint 001" within "#sidebar"
     When I follow "Wiki" within "#sidebar"
     Then I should see "Sprint Template" within ".wiki-page"
     # now check edit wiki page on version page
     When I follow "Settings" within "#main-menu"
      And I follow "Versions" within ".tabs"
      And I follow "Sprint 001" within "#tab-content-versions .versions td.name"
      And I follow "Edit wiki page" within ".contextual"
     Then I should see "Sprint Template" within "#content_text"
     # check from backlogs sprint menu does not test reliably. 2bd.
     #When I follow "Backlogs" within "#main-menu"
     # And I follow "Wiki" from the menu of a Sprint
     #Then I should see "Sprint Template" within ".wiki-page"

  Scenario: Update sprint with start date greater than end date
    Given I am viewing the master backlog
      And I want to edit the sprint named Sprint 001
      And I want to set the sprint_start_date of the sprint to 2012-03-01
      And I want to set the effective_date of the sprint to 2012-02-20
     When I update the sprint
     Then the server should return an update error
      And the error message should say "Sprint cannot end before it starts"
