Feature: Scrum master
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And the project has the following sprint:
        | name       | sprint_start_date | effective_date  |
        | Sprint 001 | today             | 1.week.from_now |
      And the project has the following stories in the product backlog:
        | position | subject | 
        | 1        | Story 1 |
        | 2        | Story 2 |
        | 3        | Story 3 |
        | 4        | Story 4 |
      And the project has the following stories in the following sprints:
        | position | subject | sprint     | story_points |
        | 1        | Story A | Sprint 001 | 1            |
        | 2        | Story B | Sprint 001 | 2            |
        | 3        | Story C | Sprint 001 | 4            |
      And the project has the following tasks:
        | subject      | story     | estimated_time | status |
        | A.1          | Story A   | 10             | new    |
        | B.1          | Story B   | 20             | new    |
        | C.1          | Story C   | 40             | new    |

  Scenario: Tasks closed AFTER remaining hours is set to 0 
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | estimated_hours | status      |
        | 1       | A.1  | 5               | In progress |
        | 1       | B.1  | 10              | In progress |
        | 2       | A.1  | 0               |             |
        | 2       | A.1  |                 | closed      |
        | 2       | C.1  | 30              | In progress |
        | 3       | B.1  | 0               |             |
        | 3       | B.1  |                 | closed      |
        | 3       | C.1  | 25              |             |
        | 4       | C.1  | 10              |             |
        | 5       | C.1  | 0               |             |
        | 5       | C.1  |                 | closed      |
      Then the values of the burndown chart should be the following:
        | day     | committed_points | points_not_resolved | estimated_hours |
        | start   | 7                | 7                   | 70              |
        | 1       | 7                | 7                   | 55              |
        | 2       | 7                | 6                   | 40              |
        | 3       | 7                | 4                   | 25              |
        | 4       | 7                | 4                   | 10              |
        | 5       | 7                | 0                   | 0               |

  Scenario: Tasks closed BEFORE remaining hours is set to 0
    Given I am viewing burndown chart for Sprint 001
      And I have done the following using the task board during the sprint:
        | day     | task | estimated_hours | status      |
        | 1       | A.1  | 5               | In progress |
        | 1       | B.1  | 10              | In progress |
        | 2       | A.1  |                 | closed      |
        | 2       | A.1  | 0               |             |
        | 2       | C.1  | 30              | In progress |
        | 3       | B.1  |                 | closed      |
        | 3       | B.1  | 0               |             |
        | 3       | C.1  | 25              |             |
        | 4       | C.1  | 10              |             |
        | 5       | C.1  |                 | closed      |
        | 5       | C.1  | 0               |             |
      Then the values of the burndown chart should be the following:
        | day     | committed_points | points_not_resolved | estimated_hours |
        | start   | 7                | 7                   | 70              |
        | 1       | 7                | 7                   | 55              |
        | 2       | 7                | 6                   | 40              |
        | 3       | 7                | 4                   | 25              |
        | 4       | 7                | 4                   | 10              |
        | 5       | 7                | 0                   | 0               |

  Scenario: New task and story added during sprint
    Given I am viewing burndown chart for Sprint 001
      And I have done the following using the task board during the sprint:
        | day     | task | estimated_hours | status      |
        | 1       | A.1  | 5               | In progress |
        | 1       | B.1  | 10              | In progress |
        | 2       | A.1  | 0               |             |
        | 2       | A.1  |                 | closed      |
        | 2       | C.1  | 30              | In progress |
      And I have added a new story story d of 4 story points
      And story d has been added to sprint 001 on day 3
      And I have added a new task to story d with subject D.1 and 40 remaining hours
      And I continue doing the following during the sprint:
        | 3       | B.1  | 0               |             |
        | 3       | B.1  |                 | closed      |
        | 3       | C.1  | 25              |             |
        | 4       | C.1  | 10              |             |
        | 4       | D.1  | 20              | in progress |
        | 5       | C.1  | 0               |             |
        | 5       | C.1  |                 | closed      |
        | 5       | D.1  | 0               |             |
        | 5       | D.1  |                 | closed      |
      Then the values of the burndown chart should be the following:
        | day     | committed_points | points_not_resolved | estimated_hours |
        | start   | 7                | 7                   | 70              |
        | 1       | 7                | 7                   | 55              |
        | 2       | 7                | 6                   | 40              |
        | 3       | 11               | 8                   | 65              |
        | 4       | 11               | 4                   | 30              |
        | 5       | 11               | 0                   | 0               |
