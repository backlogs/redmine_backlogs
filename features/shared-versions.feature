Feature: Shared versions
  As a project manager 
  I want to use shared versions
  So that I can manage release over projects

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the private-child project has the backlogs plugin enabled
      And the project6 project has the backlogs plugin enabled
      And the onlinestore project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a team member of the projects

      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | sharing   | project_id    |
        | Sprint 001 | 2010-01-01        | 2010-01-31     | hierarchy | ecookbook     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     | none      | private-child |
        | Sprint 003 | 2010-03-01        | 2010-03-31     | tree      | project6      |
        | Sprint 004 | 2010-03-01        | 2010-03-31     | system    | onlinestore   |

      And I have defined the following stories in the following sprints:
        | position | subject | sprint     | project_id    |
        | 1        | Story 1 | Sprint 001 | ecookbook     |
        | 2        | Story 2 | Sprint 001 | ecookbook     |
        | 3        | Story 3 | Sprint 001 | ecookbook     |
        | 4        | Story 4 | Sprint 002 | private-child |

      And I have defined the following tasks:
        | subject | story  |
        | Task 1  | Story 1 |

      And I have defined the following impediments:
        | subject      | sprint     | blocks  |
        | Impediment 1 | Sprint 001 | Story 1 |
        | Impediment 2 | Sprint 001 | Story 2 | 
        
  Scenario: Create a task for a story
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
     When I create the task
      And the 2nd task for Story 1 should be A Whole New Task

  Scenario: Update a task for a story
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
      And I want to edit the task named Task 1
      And I set the subject of the task to Whoa there, Sparky
     When I update the task
     Then the story named Story 1 should have 1 task named Whoa there, Sparky

  Scenario: View a taskboard
    Given I have selected the ecookbook project
     And I am viewing the taskboard for Sprint 001
     Then I should see the taskboard

  Scenario: View the burndown chart
    Given I have selected the ecookbook project
      And I am viewing the burndown for Sprint 002
     Then I should see the burndown chart

  Scenario: View sprint stories in the issues tab
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     When I view the stories of Sprint 001 in the issues tab
     Then I should see the Issues page

  Scenario: View the project stories in the issues tab
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     When I view the stories in the issues tab
     Then I should see the Issues page

  Scenario: Fetch the updated stories
    Given I have selected the ecookbook project
      And I am viewing the master backlog
     When the browser fetches stories updated since 1 week ago
     Then the server should return 3 updated stories

  Scenario: Fetch the updated tasks
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
     When the browser fetches tasks updated since 1 week ago
     Then the server should return 1 updated task

  Scenario: Fetch the updated impediments
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
     When the browser fetches impediments updated since 1 week ago
     Then the server should return 2 updated impediments

  Scenario: Fetch zero updated impediments 
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
     When the browser fetches impediments updated since 1 week from now
     Then the server should return 0 updated impediments
      
  Scenario: Copy estimate to remaining
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the estimated_hours of the task to 3
     When I create the task
     Then the request should complete successfully
     Then task A Whole New Task should have estimated_hours set to 3

  Scenario: Copy remaining to estimate
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the estimated_hours of the task to 3
     When I create the task
     Then task A Whole New Task should have estimated_hours set to 3

  Scenario: Set both estimate and remaining
    Given I have selected the ecookbook project
      And I am viewing the taskboard for Sprint 001
      And I want to create a task for Story 1
      And I set the subject of the task to A Whole New Task
      And I set the estimated_hours of the task to 8
     When I create the task
      And I want to create a task for Story 1
      And I set the subject of the task to A Second New Task
      And I set the estimated_hours of the task to 2
     When I create the task
     Then task A Whole New Task should have estimated_hours set to 8
      And story Story 1 should have estimated_hours set to 10
