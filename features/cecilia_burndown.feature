Feature: Cecilia Burndown
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have the following issue statuses available:
        | name                  | is_closed | is_default | 
        | New                   |         0 |          1 | 
        | Accepted              |         0 |          0 | 
        | Review                |         0 |          0 |                   
        | Test                  |         0 |          0 |                    
        | Closed                |         1 |          0 |                   
        | Deferred              |         0 |          0 |                   
        | Need more information |         0 |          0 |                  
        | Invalid               |         1 |          0 |                  
        | Rejected              |         1 |          0 |                 
        | Approved              |         1 |          0 | 
        | Implemented           |         1 |          0 |
      And the current time is 2012-11-20 08:00:00

      And I have defined the following stories in the product backlog:
        | subject   |
        | Story B.1 |
        | Story B.2 |
        | Story B.3 |
        | Story B.4 |

      And I have defined the following sprints:
        | name           | sprint_start_date | effective_date  |
        | Sprint 1       | 2012-11-21        | 2012-11-28      |
      And I have defined the following stories in the following sprint:
        | subject     | sprint         | points |
        | Story 1.1   | Sprint 1       | 8      |
      And I have defined the following tasks:
        | subject      | story            | estimate | status |
        | Task 1.1.1   | Story 1.1        | 40       | New    |

  Scenario: See burndown chart for Sprint 1 in a correct way directly
    Given I am viewing the burndown for Sprint 1
    Then the sprint burndown should be:
      | day     | points_committed | points_to_resolve | hours_remaining |
      | start   | 8                | 8                 | 40              |
