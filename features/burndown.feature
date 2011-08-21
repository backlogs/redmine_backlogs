Feature: Scrum master
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                    |
        | Assigned    |         0 |          0 |                    |
        | In Progress |         0 |          0 |                    |
        | Resolved    |         0 |          0 |                    |
        | Feedback    |         0 |          0 |                    |
        | Closed      |         1 |          0 |                    |
        | Accepted    |         1 |          0 |                    |
        | Rejected    |         1 |          0 |                  1 |
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
        | position | subject | sprint     | points | day |
        | 1        | Story A | Sprint 001 | 1      |     |
        | 2        | Story B | Sprint 001 | 2      |     |
        | 3        | Story C | Sprint 001 | 4      |     |
      And the project has the following tasks:
        | subject      | story     | estimate | status | offset |
        | A.1          | Story A   | 10       | New    | 1h     |
        | B.1          | Story B   | 20       | New    | 1h     |
        | C.1          | Story C   | 40       | New    | 1h     |

  Scenario: Tasks closed AFTER remaining hours is set to 0 
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In progress |
        | 1       | B.1  | 10        | In progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In progress |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  | 0         |             |
        | 5       | C.1  |           | Closed      |
      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 0                 | 0               |

  Scenario: Tasks closed BEFORE remaining hours is set to 0
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In progress |
        | 1       | B.1  | 10        | In progress |
        | 2       | A.1  |           | Closed      |
        | 2       | A.1  | 0         |             |
        | 2       | C.1  | 30        | In progress |
        | 3       | B.1  |           | Closed      |
        | 3       | B.1  | 0         |             |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  |           | Closed      |
        | 5       | C.1  | 0         |             |

      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 0                 | 0               |

  Scenario: New task and story added during sprint
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In progress |
        | 1       | B.1  | 10        | In progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In progress |

      And the project has the following stories in the following sprints:
        | subject | sprint     | points | day |
        | Story D | Sprint 001 | 4      | 3   |

      And the project has the following tasks:
        | subject      | story     | estimate | status | offset |
        | D.1          | Story D   | 40       | New    | 1h     |

      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 4       | D.1  | 20        | In Progress |
        | 5       | C.1  | 0         |             |
        | 5       | C.1  |           | Closed      |
        | 5       | D.1  | 0         |             |
        | 5       | D.1  |           | Closed      |

      Then show me the estimated_hours journal for A.1
      Then show me the burndown for task A.1
      Then show me the estimated_hours journal for B.1
      Then show me the burndown for task B.1
      Then show me the estimated_hours journal for C.1
      Then show me the burndown for task C.1
      Then show me the estimated_hours journal for D.1
      Then show me the burndown for task D.1
      #Then show me the story_points journal for Story A
      #Then show me the story burndown for Story A
      #Then show me the story_points journal for Story B
      #Then show me the story burndown for Story B
      #Then show me the story_points journal for Story C
      #Then show me the story burndown for Story C
      #Then show me the story_points journal for Story D
      #Then show me the story burndown for Story D
      Then show me the sprint burndown

      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 11               | 8                 | 65              |
        | 4       | 11               | 4                 | 30              |
        | 5       | 11               | 0                 | 0               |
